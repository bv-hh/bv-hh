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
  include WithAllrisPage

  SMALL_INQUIRY_TYPES = ['Kleine Anfrage nach § 24 BezVG', 'Anfrage gem. § 24 BezVG (Kleine Anfrage)', 'Kleine Anfrage öffentlich', 'Kleine Anfrage gem. § 24 BezVG']
  LARGE_INQUIRY_TYPES = ['Große Anfrage nach § 24 BezVG', 'Anfrage gem. § 24 BezVG (Große Anfrage)', 'Große Anfrage öffentlich', 'Große Anfrage gem. § 24 BezVG']
  STATE_INQUIRY_TYPES = ['Anfrage nach § 27 BezVG', 'Anfrage gem. § 27 BezVG', 'Auskunftsersuchen', 'Anfrage gem. § 27 BezVG']

  NON_PUBLIC = 'Keine Information verf&uuml;gbar'
  AUTH_REDIRECT = 'noauth.asp'

  # Labels that open a section of a vo020 page, matched against the start of
  # the section's first paragraph (see Parsing.sections). Unlabelled sections
  # belong to the content.
  SECTION_LABELS = {
    content: /\A(Sachverhalt( und Petitum)?\b:?|Hintergrund:)/,
    resolution: %r{\A(Petitum\b(\s*/\s*(Beschluss\w*)?)?:?|Beschluss:)},
    attached: %r{\AAnlagen?(/n)?:},
  }.freeze

  # The expression behind documents_expr_idx, for a full-text query that has to
  # be answered by that index.
  SEARCH_VECTOR = "(setweight(to_tsvector('german', documents.title), 'A') || " \
                  "setweight(to_tsvector('german', documents.full_text), 'B'))"

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
  scope :small_inquiries, -> { where(kind: SMALL_INQUIRY_TYPES) }
  scope :large_inquiries, -> { where(kind: LARGE_INQUIRY_TYPES) }
  scope :state_inquiries, -> { where(kind: STATE_INQUIRY_TYPES) }
  scope :authored_by, ->(name) { where('documents.title ILIKE :name OR documents.author ILIKE :name', name: "%#{name}%") }
  scope :complete, -> { where.not(title: nil) }
  scope :include_meetings, -> { includes(:meetings).left_joins(:meetings) }
  scope :in_date_range, ->(range) { joins(agenda_items: :meeting).where('meetings.date' => range) }
  scope :in_last_months, ->(months) { in_date_range((months + 1).months.ago.beginning_of_month..1.month.ago.end_of_month) }
  scope :in_last_days, ->(days) { in_date_range(days.days.ago.beginning_of_day..Time.zone.now) }
  scope :committee, ->(committee) { joins(agenda_items: :meeting).where('meetings.committee_id' => committee) }
  scope :since_number, ->(number) { where(documents: { number: number.. }) }
  scope :locations_not_extracted, -> { where(locations_extracted_at: nil) }
  scope :topics_outdated, -> { where(topics_version: nil).or(where.not(topics_version: Topic::VERSION)) }
  scope :current_legislation, ->(district) { where(district: district).since_number(district.first_legislation_number) }
  scope :children, ->(number) { where('number ILIKE ?', "#{number}.%") }
  scope :parsed_before, ->(version) { where(parser_version: nil).or(where(parser_version: ...version)) }

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

    query.order(ranking: :desc)
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
    html = parse_page(source)
    save!
    return self if html.nil?

    store_page(source)
    retrieve_attachments(html)
    retrieve_images(html)

    extract_locations_later! if full_text.present?
  end

  # Parses the stored page again, for when only the parser changed: no request
  # to ALLRIS, and attachments and images stay as they are.
  def reparse!
    update_from_page!(allris_page.body)
  end

  # Parses a fresh copy of the page, for a document an older parser read
  # (RefetchDocumentsJob). Only the page is read: attachments and images stay
  # as they are, since ALLRIS may have dropped files archived here years ago.
  # A page that is not public now, or a login redirect, which ALLRIS serves
  # when it has a bad moment, leaves a document the site has shown for years
  # as it is.
  def refetch!(source = Net::HTTP.get(URI(allris_url)))
    return update!(parser_version: Parsing::VERSION) if non_public_page?(source)

    update_from_page!(source)
    store_page(source)
  end

  # Re-extraction reads the whole text and its attachments, so only when the
  # text actually changed. Topics follow extraction; a new title alone changes
  # only them.
  def update_from_page!(source)
    parse_page(source)
    save!

    if saved_change_to_full_text? && full_text.present?
      extract_locations_later!
    elsif saved_change_to_title?
      assign_topics_later!
    end
  end

  # Sets the attributes from an ALLRIS vo020 page and returns its content table,
  # or nil for a page that is not public.
  def parse_page(source)
    self.parser_version = Parsing::VERSION

    if non_public_page?(source)
      self.non_public = true
      return nil
    end

    html = Parsing.parse(source)

    headline = html.css('h1').first&.text
    self.number = headline&.gsub('Drucksache -', '')&.gsub('Vorlage -', '')&.squish

    html = html.css('table.risdeco').first

    retrieve_meta(html)
    retrieve_body(html)
    html
  end

  def non_public_page?(source)
    source.include?(NON_PUBLIC) || source.include?(AUTH_REDIRECT)
  end

  def retrieve_meta(html)
    self.title = clean_linebreaks(clean_html(html.css('td.text1').first))
    self.kind = clean_html(html.css('td.text4').first)

    self.author = clean_html(html.css('td.text4')[1]) if kind.include?('Kleine Anfrage') || kind.include?('Große Anfrage')
  end

  def retrieve_body(html)
    sections = Parsing.sections(html.css('td[bgcolor=white] > div'), SECTION_LABELS).group_by { |section| section.key || :content }

    self.content = Parsing.clean_sections(sections.fetch(:content, []))
    self.resolution = Parsing.clean_sections(sections.fetch(:resolution, []))
    self.attached = Parsing.clean_sections(sections.fetch(:attached, []))

    self.full_text = [content, resolution].filter_map { |part| html_to_text(part) }.join("\n")
  end

  def extract_attachment_table(html)
    html.css('table.tk1').first
  end

  def retrieve_images(html)
    main_content = html.xpath('.//title[contains(., "ALLRIS® Office Integration")]/following-sibling::div')
    main_content.css('img').each do |image_tag|
      src = image_tag['src']&.squish
      next if src.blank? || images.any? { |image| image.filename.to_s == File.basename(src) }

      io = URI.parse("#{district.allris_base_url}/bi/#{src}").open
      images.attach(io:, filename: File.basename(src))
    end
  end

  def retrieve_images!
    source = Net::HTTP.get(URI(allris_url))
    html = Parsing.parse(source)
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

  # Attachments carry the substance of a Drucksache often enough to matter: the
  # body is frequently a cover note and the plan, the Anordnung or the reply
  # lives in the PDF. Their extracted text is already stored, so searching it
  # costs nothing extra.
  def extractable_text
    [title, full_text, attachments_content].compact_blank.join(' ').scrub
  end

  def attachments_content
    ActionController::Base.helpers.strip_tags(attachments.map(&:content).join(' ')).squish.delete("\n")
  end

  def extract_locations_later!
    ExtractDocumentLocationsJob.perform_later(self)
  end

  # Every name comes from a local register, found by whole-word lookup:
  # streets, Stadtteile and POIs by name, stations behind a transit prefix.
  # There used to be an NER model here as well. Most of what it proposed was
  # agency acronyms and plain nouns no register knows, and on a sample of 1000
  # documents it found about half the Stadtteile and POIs the registers do.
  def extract_locations!
    all_text = extractable_text
    return if all_text.blank?

    self.locations_extracted_at = Time.zone.now
    self.extracted_locations = extracted_names(all_text)
    self.quarters = extracted_quarters
    self.stations = TransitGazetteer.match(all_text)
    save!

    assign_locations_later!
  end

  def extracted_names(text)
    (StreetGazetteer.match(text) + QuarterGazetteer.match(text) + PoiGazetteer.match(text)).uniq
  end

  def assign_locations_later!
    AssignDocumentLocationsJob.perform_later(self)
  end

  # Links the document to exactly the places its names and stations resolve
  # to, and drops any other link. Assignment used to be additive, so a link
  # outlived the name that made it: re-extraction could change the names, but
  # never take a place off the document.
  def assign_locations!
    locations = (extracted_name_locations + station_locations).uniq

    locations.each { |location| document_locations.find_or_create_by!(location: location) }
    document_locations.where.not(location_id: locations.map(&:id)).delete_all
  end

  def assign_topics_later!
    AssignDocumentTopicsJob.perform_later(self)
  end

  # Written with update_columns: topics are derived data, and touching
  # updated_at would reorder RefetchDocumentsJob's queue and the feeds.
  def assign_topics!
    topics = TopicClassifier.new(self).topics
    attributes = { topics_version: Topic::VERSION }
    attributes[:topics] = topics unless topics.sort == self.topics.sort
    update_columns(attributes) # rubocop:disable Rails/SkipsModelValidations
  end

  def topic_records
    topics.filter_map { |key| Topic.find(key) }
  end

  def extracted_name_locations
    extracted_locations.to_a.reject { |name| from_local_committee?(name) }.flat_map do |name|
      Location.determine_locations(name, district)
    end
  end

  # Stations named behind a transit prefix. A separate path because a station's
  # bare name means something else — "Barmbek" is a Stadtteil, "Habichtstraße"
  # a street — so it is reachable only through Poi.transit_for, never through
  # the plain name lookup.
  def station_locations
    stations.to_a.flat_map { |station| Location.determine_station_locations(station, district) }
  end

  # Stadtteile named outright in the text. Recorded on the document rather than
  # geocoded, because a Stadtteil is an area and has no single point to pin.
  #
  # A regional committee is named after the Stadtteile it covers, so its own
  # name would otherwise tag every one of its Drucksachen — the same reason
  # extracted_name_locations skips those.
  def extracted_quarters
    Quarter.canonical_names(extracted_locations).reject { |name| from_local_committee?(name) }
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

  def as_json
    {
      id: id,
      number: number,
      title: title,
      kind: kind,
      author: author,
      content: strip_tags(content),
      resolution: strip_tags(resolution),
      attached: strip_tags(attached),
      created_at: created_at,
      updated_at: updated_at,
      district: district.name,
      meetings: meetings.map do |meeting|
        {
          id: meeting.id,
          title: meeting.title,
          date: meeting.date,
          start_time: meeting.start_time,
          end_time: meeting.end_time,
        }
      end,
    }
  end
end
