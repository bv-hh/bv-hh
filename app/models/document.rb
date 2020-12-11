
class Document < ApplicationRecord

  NON_PUBLIC = 'Keine Information verf&uuml;gbar'

  belongs_to :district

  validates :allris_id, presence: true

  scope :latest_first, -> { order(number: :desc) }

  default_scope -> { where(non_public: false) }

  def self.search(term, root = nil)
    parsed_term = term.squish.gsub(/[^a-z0-9öäüß ]/i, '').split.join(' & ')
    search = <<~SQL.squish
      (setweight(to_tsvector('german', documents.title),'A') ||
      setweight(to_tsvector('german', documents.full_text), 'B'))
    SQL

    query = root || Document.all
    query_base = query
    query = query.where("#{search} @@ to_tsquery('german', ?)", parsed_term)
    query = query.or(query_base.where(number: term))

    ordering = sanitize_sql_for_order [Arel.sql("ts_rank(#{search}, to_tsquery('german', ?)) DESC, documents.title"), parsed_term]
    query.order(ordering)
  end

  def self.prefix_search(term, root = nil)
    term = '' if term.nil?

    query = root || Document.all
    query = query.where('documents.title ILIKE :term OR documents.number ILIKE :term', term: "#{term.downcase}%")

    ordering = sanitize_sql_for_order [Arel.sql('(CASE WHEN documents.number ILIKE :term THEN 2 ELSE 0 END) + (CASE WHEN documents.title ILIKE ? THEN 1 ELSE 0 END) DESC, documents.title'), term: "#{term}%"]
    query.order(ordering)
  end

  def retrieve_from_allris
    source = URI.open(allris_url, &:read)

    if source.include? NON_PUBLIC
      self.non_public = true
      return
    end

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

    self.number = html.css('h1').first&.text&.gsub('Drucksache -', '')&.squish

    html = html.css('table.risdeco').first

    self.title = clean_html(html.css('td.text1').first)
    self.kind = clean_html(html.css('td.text4').first)

    self.content = retrieve_xpath_div(html, 'Sachverhalt:')
    self.resolution = retrieve_xpath_div(html, 'Petitum/Beschluss:')
    self.resolution ||= retrieve_xpath_div(html, 'Petitum/Beschlussvorschlag:')

    self.full_text = ActionController::Base.helpers.strip_tags(self.content)
    if self.resolution.present?
      self.full_text += ' '
      self.full_text += ActionController::Base.helpers.strip_tags(self.resolution)
    end
  end

  def allris_url
    raise 'Allris ID missing' if allris_id.blank?

    "#{district.allris_base_url}/bi/vo020.asp?VOLFDNR=#{allris_id}"
  end

  SANITIZER = Rails::Html::SafeListSanitizer.new
  SCRUBBER = Rails::Html::TargetScrubber.new
  SCRUBBER.tags = %w[font tabref div iframe h1 h2]
  SCRUBBER.attributes = %w[class target cellpadding cellspacing width height start type]

  XPATHS_TO_REMOVE = %w{.//script .//form comment()}

  def clean_html(node)
    return nil if node.nil?

    node.xpath(*XPATHS_TO_REMOVE).remove
    cleaned = SANITIZER.sanitize(node.inner_html, scrubber: SCRUBBER)
    cleaned = cleaned.gsub(/font-family:([^;]*);/, '').gsub(/font-size:([^;]*);/, '')
    cleaned
  end

  def retrieve_xpath_div(html, xpath_content)
    clean_html(html.xpath("//span[contains(text(), '#{xpath_content}')]").first&.ancestors('div')&.first)&.sub(xpath_content, '')
  end

  def to_param
    "#{title.parameterize}-#{id}"
  end
end
