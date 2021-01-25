# frozen_string_literal: true

require 'net/http'

class Document < ApplicationRecord
  include Parsing

  SMALL_INQUIRY_TYPES = ['Kleine Anfrage nach § 24 BezVG', 'Anfrage gem. § 24 BezVG (Kleine Anfrage)', 'Kleine Anfrage öffentlich', 'Kleine Anfrage gem. § 24 BezVG']
  LARGE_INQUIRY_TYPES = ['Große Anfrage nach § 24 BezVG', 'Anfrage gem. § 24 BezVG (Große Anfrage)', 'Große Anfrage öffentlich', 'Große Anfrage gem. § 24 BezVG']
  STATE_INQUIRY_TYPES = ['Anfrage nach § 27 BezVG', 'Anfrage gem. § 27 BezVG', 'Auskunftsersuchen', 'Anfrage gem. § 27 BezVG']

  NON_PUBLIC = 'Keine Information verf&uuml;gbar'
  AUTH_REDIRECT = 'noauth.asp'

  belongs_to :district

  has_many :agenda_items, dependent: :nullify
  has_many :meetings, through: :agenda_items
  has_many :attachments, dependent: :destroy

  validates :allris_id, presence: true

  scope :latest_first, -> { order(number: :desc) }
  scope :proposals, -> { where('kind ILIKE ?', '%Antrag%') }
  scope :proposals_by, ->(name) { proposals.where('title ILIKE ?', "%#{name}%") }
  scope :small_inquiries, ->(name) { where(kind: SMALL_INQUIRY_TYPES).where('author ILIKE ?', "%#{name}%") }
  scope :large_inquiries, ->(name) { where(kind: LARGE_INQUIRY_TYPES).where('author ILIKE ?', "%#{name}%") }
  scope :state_inquiries, ->(name) { where(kind: STATE_INQUIRY_TYPES).where('title ILIKE ?', "%#{name}%") }
  scope :complete, -> { where.not(title: nil) }
  scope :include_meetings, -> { includes(:meetings).left_joins(:meetings) }
  scope :in_date_range, ->(range) { joins(agenda_items: :meeting).where('meetings.date' => range) }
  scope :in_last_months, ->(months) { in_date_range((months + 1).months.ago.beginning_of_month..1.month.ago.end_of_month) }
  scope :committee, ->(committee) { joins(agenda_items: :meeting).where('meetings.committee_id' => committee) }
  scope :since_number, ->(number) { where('documents.number >= ?', number) }

  default_scope -> { where(non_public: false) }

  def self.search(term, root = nil, ordering = :relevance)
    terms = term.squish.gsub(/[^a-z0-9öäüß ]/i, '').split
    exact_term = terms.join(' & ')

    search = <<~SQL.squish
      (setweight(to_tsvector('german', documents.title),'A') ||
      setweight(to_tsvector('german', documents.full_text), 'B'))
    SQL

    query = root || Document.all
    query_base = query
    query = query.where("#{search} @@ to_tsquery('german', ?)", exact_term)
    query = query.or(query_base.where(number: term))

    if ordering == :relevance
      ordering = sanitize_sql_for_order [Arel.sql("ts_rank(#{search}, to_tsquery('german', ?)) DESC, documents.number DESC"), exact_term]
      query.order(ordering)
    elsif ordering == :date
      query.order(number: :desc)
    else
      raise "Unknown ordering #{ordering}"
    end
  end

  def self.prefix_search(term, root = nil)
    term = '' if term.nil?

    query = root || Document.all
    query = query.where('documents.title ILIKE :term OR documents.number ILIKE :term', term: "#{term.downcase}%")

    ordering = sanitize_sql_for_order [Arel.sql('(CASE WHEN documents.number ILIKE :term THEN 2 ELSE 0 END) + (CASE WHEN documents.title ILIKE ? THEN 1 ELSE 0 END) DESC, documents.title'), { term: "#{term}%" }]
    query.order(ordering)
  end

  def self.format_document(content)
    link_documents(content)
  end

  def retrieve_from_allris!(source = Net::HTTP.get(URI(allris_url)))
    if source.include?(NON_PUBLIC) || source.include?(AUTH_REDIRECT)
      self.non_public = true
      return self
    end

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

    self.number = html.css('h1').first&.text&.gsub('Drucksache -', '')&.squish

    html = html.css('table.risdeco').first

    retrieve_meta(html)
    retrieve_body(html)

    save!

    retrieve_attachments(html)
  end

  def retrieve_meta(html)
    self.title = clean_linebreaks(clean_html(html.css('td.text1').first))
    self.kind = clean_html(html.css('td.text4').first)

    self.author = clean_html(html.css('td.text4')[1]) if kind.include?('Kleine Anfrage') || kind.include?('Große Anfrage')
  end

  def retrieve_body(html) # rubocop:disable Metrics/AbcSize
    self.content = retrieve_xpath_div(html, 'Sachverhalt:')
    self.content = retrieve_xpath_div(html, 'Sachverhalt') if content.nil?
    self.content = retrieve_xpath_div(html, 'Hintergrund:') if content.nil?
    self.content = clean_html(html.css('td[bgcolor=white] > div')[0]) if content.nil?
    self.resolution = retrieve_xpath_div(html, 'Petitum/Beschluss:')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum/Beschlussvorschlag:')
    self.attached = retrieve_xpath_div(html, 'Anlage/n:')

    self.full_text = strip_tags(content) || ''
    if self.resolution.present?
      self.full_text += ' '
      self.full_text += strip_tags(self.resolution)
    end
  end

  require 'open-uri'

  def retrieve_attachments(html)
    upper_table = html.css('table.tk1').first
    upper_table.css('a[title*="(Öffnet Dokument in neuem Fenster)"]').each do |attachment_link|
      href = attachment_link['href']
      uri = URI.parse(href)

      name = attachment_link.text

      next if attachments.exists?(name: name)

      filename = File.basename(uri.path)
      io = URI.parse("#{district.allris_base_url}/bi/#{href}").open

      attachment = attachments.create! name: name, district: district
      attachment.file.attach(io: io, filename: filename)
      attachment.extract_later!
    end
  end

  def retrieve_attachments!
    source = Net::HTTP.get(URI(allris_url))
    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))
    html = html.css('table.risdeco').first

    retrieve_attachments(html)
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
end
