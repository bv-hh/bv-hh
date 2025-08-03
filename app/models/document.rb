# frozen_string_literal: true

# == Schema Information
#
# Table name: documents
#
#  id                     :bigint           not null, primary key
#  attached               :text
#  author                 :string
#  content                :text
#  extracted_locations    :string           default([]), is an Array
#  full_text              :text
#  kind                   :string
#  locations_extracted_at :datetime
#  non_public             :boolean          default(FALSE)
#  number                 :string
#  resolution             :text
#  title                  :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  allris_id              :integer
#  district_id            :bigint
#
# Indexes
#
#  documents_expr_idx              (((setweight(to_tsvector('german'::regconfig, (title)::text), 'A'::"char") || setweight(to_tsvector('german'::regconfig, full_text), 'B'::"char")))) USING gin
#  full_text_gin_trgm_idx          (full_text) USING gin
#  full_text_gist_trgm_idx         (full_text) USING gist
#  index_documents_on_allris_id    (allris_id)
#  index_documents_on_district_id  (district_id)
#  index_documents_on_number       (number)
#  title_gin_trgm_idx              (title) USING gin
#  title_gist_trgm_idx             (title) USING gist
#
require 'net/http'

class Document < ApplicationRecord
  include Parsing
  include WithAttachments

  SMALL_INQUIRY_TYPES = ['Kleine Anfrage nach § 24 BezVG', 'Anfrage gem. § 24 BezVG (Kleine Anfrage)', 'Kleine Anfrage öffentlich', 'Kleine Anfrage gem. § 24 BezVG']
  LARGE_INQUIRY_TYPES = ['Große Anfrage nach § 24 BezVG', 'Anfrage gem. § 24 BezVG (Große Anfrage)', 'Große Anfrage öffentlich', 'Große Anfrage gem. § 24 BezVG']
  STATE_INQUIRY_TYPES = ['Anfrage nach § 27 BezVG', 'Anfrage gem. § 27 BezVG', 'Auskunftsersuchen', 'Anfrage gem. § 27 BezVG']

  NON_PUBLIC = 'Keine Information verf&uuml;gbar'
  AUTH_REDIRECT = 'noauth.asp'

  NER_THRESHOLD = 0.4

  belongs_to :district

  has_many :agenda_items, dependent: :nullify
  has_many :meetings, through: :agenda_items
  has_many :committees, through: :meetings
  has_many :attachments, as: :attachable, dependent: :destroy

  has_many :document_locations, dependent: :destroy
  has_many :locations, through: :document_locations

  has_many_attached :images

  validates :allris_id, presence: true

  scope :latest_first, -> { order(number: :desc) }
  scope :proposals, -> { where('documents.kind ILIKE ?', '%Antrag%') }
  scope :proposals_by, ->(name) { proposals.where('documents.title ILIKE ?', "%#{name}%") }
  scope :small_inquiries, ->(name) { where(kind: SMALL_INQUIRY_TYPES).where('author ILIKE ?', "%#{name}%") }
  scope :large_inquiries, ->(name) { where(kind: LARGE_INQUIRY_TYPES).where('author ILIKE ?', "%#{name}%") }
  scope :state_inquiries, ->(name) { where(kind: STATE_INQUIRY_TYPES).where('title ILIKE ?', "%#{name}%") }
  scope :complete, -> { where.not(title: nil) }
  scope :include_meetings, -> { includes(:meetings).left_joins(:meetings) }
  scope :in_date_range, ->(range) { joins(agenda_items: :meeting).where('meetings.date' => range) }
  scope :in_last_months, ->(months) { in_date_range((months + 1).months.ago.beginning_of_month..1.month.ago.end_of_month) }
  scope :committee, ->(committee) { joins(agenda_items: :meeting).where('meetings.committee_id' => committee) }
  scope :since_number, ->(number) { where(documents: { number: number.. }) }
  scope :locations_not_extracted, -> { where(locations_extracted_at: nil) }
  scope :no_embeddings, -> { where(embeddings_created: false) }
  scope :current_legislation, ->(district) { where(district: district).since_number(district.first_legislation_number) }
  scope :children, ->(number) { where('number ILIKE ?', "#{number}.%") }

  default_scope -> { where(non_public: false) }


  def self.search(term, root: nil, attachments: false, order: :relevance)
    terms = term.squish.gsub(/[^a-z0-9öäüß ]/i, '').split
    exact_term = terms.join(' & ')

    search = <<~SQL.squish
      (setweight(to_tsvector('german', documents.title),'A') ||
      setweight(to_tsvector('german', documents.full_text), 'B')
    SQL

    query = root || Document.all

    if attachments
      query = query.left_outer_joins(:attachments)
      search += " || setweight(to_tsvector('german', coalesce(attachments.content, '')), 'C'))"
    else
      search += ')'
    end

    if order == :relevance
      order = sanitize_sql_for_order [Arel.sql("ts_rank(#{search}, to_tsquery('german', ?))"), exact_term]
    elsif order == :date
      order = 'documents.number'
    else
      raise "Invalid order #{order}"
    end

    query = query.distinct('documents.id').select("#{order} AS ranking, documents.*")
    query = query.where("#{search} @@ to_tsquery('german', ?)", exact_term)

    query.order('ranking DESC')
  end

  def self.prefix_search(term, root = nil)
    term = '' if term.nil?

    query = root || Document.all
    query = query.where('documents.title ILIKE :term OR documents.number ILIKE :term OR documents.full_text ILIKE :term', term: "%#{term.downcase}%")

    ordering = sanitize_sql_for_order [Arel.sql('(CASE WHEN documents.number ILIKE ? THEN 2 ELSE 0 END) + (CASE WHEN documents.title ILIKE ? THEN 1 ELSE 0 END) DESC, documents.title'), "#{term}%", "#{term}%"]
    query.order(ordering)
  end

  def self.format_document(content)
    link_documents(content)
  end

  def retrieve_from_allris!(source = Net::HTTP.get(URI(allris_url)))
    if source.include?(NON_PUBLIC) || source.include?(AUTH_REDIRECT)
      self.non_public = true
      save!
      return self
    end

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

    headline = html.css('h1').first&.text
    self.number = headline&.gsub('Drucksache -', '')&.gsub('Vorlage -', '')&.squish

    html = html.css('table.risdeco').first

    retrieve_meta(html)
    retrieve_body(html)

    save!

    retrieve_attachments(html)
    retrieve_images(html)

    extract_locations_later! if content.present?
  end

  def retrieve_meta(html)
    self.title = clean_linebreaks(clean_html(html.css('td.text1').first))
    self.kind = clean_html(html.css('td.text4').first)

    self.author = clean_html(html.css('td.text4')[1]) if kind.include?('Kleine Anfrage') || kind.include?('Große Anfrage')
  end

  def retrieve_body(html)
    retrieve_content(html)
    retrieve_resolution(html)

    self.attached = retrieve_xpath_div(html, 'Anlage/n:')

    self.full_text = strip_tags(content) || ''
    if resolution.present?
      self.full_text += ' '
      self.full_text += strip_tags(resolution)
    end
  end

  def retrieve_content(html)
    self.content = retrieve_xpath_div(html, 'Sachverhalt:')
    self.content ||= retrieve_xpath_div(html, 'Sachverhalt')
    self.content ||= retrieve_xpath_div(html, 'Hintergrund:')
    self.content ||= clean_html(html.css('td[bgcolor=white] > div')[0])
  end

  def retrieve_resolution(html)
    self.resolution = retrieve_xpath_div(html, 'Petitum/Beschluss:')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum/Beschlussvorschlag:')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum/Beschlussempfehlung:')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum/')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum:')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum')
  end

  def extract_attachment_table(html)
    html.css('table.tk1').first
  end

  def retrieve_images(html)
    main_content = html.xpath('.//title[contains(., "ALLRIS® Office Integration")]/following-sibling::div')
    main_content.css('img').each do |image_tag|
      src = image_tag['src']&.squish
      if src.present?
        io = URI.parse("#{district.allris_base_url}/bi/#{src}").open
        images.attach(io:, filename: File.basename(src))
      end
    end
  end

  def retrieve_images!
    source = Net::HTTP.get(URI(allris_url))
    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))
    html = html.css('table.risdeco').first

    retrieve_images(html)
    save!
  end

  def allris_url
    raise 'Allris ID missing' if allris_id.blank?

    "#{district.allris_base_url}/bi/vo020.asp?VOLFDNR=#{allris_id}"
  end

  def update_later!
    UpdateDocumentJob.perform_later(self) if needs_update?
  end

  def to_param
    "#{title.parameterize}-#{id}"
  end

  def complete?
    title.present?
  end

  def needs_update?
    !complete? || (updated_at < 4.hours.ago)
  end

  def attachments_content
    ActionController::Base.helpers.strip_tags(attachments.map(&:content).join(' ')).squish.delete("\n")
  end


  def extract_locations_later!
    ExtractDocumentLocationsJob.perform_later(self)
  end

  def extract_locations!
    all_text = "#{title} #{full_text}"
    return if all_text.blank?

    ner_locations = NerModel.model.doc(all_text).entities.filter_map do |entity|
      next if entity[:text].blank?

      entity[:text].gsub(/[^0-9a-zöäüß\- ]/i, '') if entity[:tag] == 'LOCATION' && entity[:score] >= NER_THRESHOLD
    end.uniq

    self.locations_extracted_at = Time.zone.now
    self.extracted_locations = ner_locations
    save!

    assign_locations_later! if ner_locations.present?
  end

  def assign_locations_later!
    AssignDocumentLocationsJob.perform_later(self)
  end

  def assign_locations!
    return if extracted_locations.blank?

    extracted_locations.each do |extracted_location|
      next if from_local_committee?(extracted_location)

      Location.determine_locations(extracted_location, district).each do |location|
        document_locations.find_or_create_by!(location: location)
      end
    end
  end

  def from_local_committee?(location_name)
    return false if location_name.blank?

    committees.any? do |committee|
      committee.matches_area?(location_name)
    end
  end

  def related_documents
    if number&.include?('.')
      original_number = number.split('.').first
      children = district.documents.where.not(id: id).children(original_number)
      parent = district.documents.where.not(id: id).where(number: original_number)
      parent.or(children)
    else
      district.documents.where.not(id: id).children(number)
    end
  end

  private

end
