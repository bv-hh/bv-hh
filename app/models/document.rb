# frozen_string_literal: true

require 'net/http'

class Document < ApplicationRecord
  include Parsing

  NON_PUBLIC = 'Keine Information verf&uuml;gbar'

  belongs_to :district

  has_many :agenda_items, dependent: :nullify
  has_many :meetings, through: :agenda_items

  validates :allris_id, presence: true

  scope :latest_first, -> { order(number: :desc) }
  scope :proposals, ->(name) { where('title ILIKE ?', '%Antrag%').where('title ILIKE ?', "%#{name}%") }
  scope :small_inquiries, ->(name) { where(kind: 'Kleine Anfrage nach § 24 BezVG').where('author ILIKE ?', "%#{name}%") }
  scope :large_inquiries, ->(name) { where(kind: 'Große Anfrage nach § 24 BezVG').where('author ILIKE ?', "%#{name}%") }
  scope :state_inquiries, ->(name) { where(kind: 'Anfrage nach § 27 BezVG').where('title ILIKE ?', "%#{name}%") }
  scope :complete, -> { where.not(title: nil) }
  scope :include_meetings, -> { includes(:meetings).joins(:meetings).merge(Meeting.latest_first) }

  default_scope -> { where(non_public: false) }

  def self.search(term, root = nil)
    terms = term.squish.gsub(/[^a-z0-9öäüß ]/i, '').split
    exact_term = terms.join(' & ')
    prefix_term = terms.map{|t| "#{t}:*"}.join(' & ')
    search = <<~SQL.squish
      (setweight(to_tsvector('german', documents.title),'A') ||
      setweight(to_tsvector('german', documents.title),'A') ||
      setweight(to_tsvector('german', documents.full_text), 'B'))
    SQL

    query = root || Document.all
    query_base = query
    query = query.where("#{search} @@ to_tsquery('german', ?)", exact_term)
    query = query.or(query_base.where("#{search} @@ to_tsquery('german', ?)", prefix_term))
    query = query.or(query_base.where(number: term))

    ordering = sanitize_sql_for_order [Arel.sql("ts_rank(#{search}, to_tsquery('german', ?)) DESC, documents.title"), exact_term]
    query.order(ordering)
  end

  def self.prefix_search(term, root = nil)
    term = '' if term.nil?

    query = root || Document.all
    query = query.where('documents.title ILIKE :term OR documents.number ILIKE :term', term: "#{term.downcase}%")

    ordering = sanitize_sql_for_order [Arel.sql('(CASE WHEN documents.number ILIKE :term THEN 2 ELSE 0 END) + (CASE WHEN documents.title ILIKE ? THEN 1 ELSE 0 END) DESC, documents.title'), { term: "#{term}%" }]
    query.order(ordering)
  end

  def retrieve_from_allris # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/AbcSize
    source = Net::HTTP.get(URI(allris_url))

    if source.include? NON_PUBLIC
      self.non_public = true
      return
    end

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

    self.number = html.css('h1').first&.text&.gsub('Drucksache -', '')&.squish

    html = html.css('table.risdeco').first

    self.title = clean_html(html.css('td.text1').first)
    self.kind = clean_html(html.css('td.text4').first)

    self.author = clean_html(html.css('td.text4')[1]) if kind.include?('Kleine Anfrage') || kind.include?('Große Anfrage')

    self.content = retrieve_xpath_div(html, 'Sachverhalt:')
    self.content = retrieve_xpath_div(html, 'Sachverhalt') if content.nil?
    self.content = retrieve_xpath_div(html, 'Hintergrund:') if content.nil?
    self.content = clean_html(html.css('td[bgcolor=white] > div')[0]) if content.nil?
    self.resolution = retrieve_xpath_div(html, 'Petitum/Beschluss:')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum/Beschlussvorschlag:')

    self.full_text = strip_tags(content) || ''
    if self.resolution.present?
      self.full_text += ' '
      self.full_text += strip_tags(self.resolution)
    end

    self
  end

  def allris_url
    raise 'Allris ID missing' if allris_id.blank?

    "#{district.allris_base_url}/bi/vo020.asp?VOLFDNR=#{allris_id}"
  end

  def to_param
    "#{title.parameterize}-#{id}"
  end
end
