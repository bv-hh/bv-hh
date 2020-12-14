
class Meeting < ApplicationRecord
  include Parsing

  belongs_to :district

  has_many :agenda_items

  validates :district, presence: true

  scope :latest_first, -> { order(date: :desc) }

  def retrieve_from_allris
    html = Nokogiri::HTML.parse(URI.open(allris_url), nil, 'ISO-8859-1')

    full_title = html.css('h1').first&.text&.gsub('Tagesordnung -', '')&.squish
    self.title = full_title.split('Bitte beachten Sie:').first.squish

    html = html.css('table.risdeco').first

    self.committee = clean_html(html.css('td.text1')[1])
    self.date = clean_html(html.css('td.text2').first)&.split(',')&.last&.squish
    self.time = html.css('td.text2')[1].text
    self.room = html.css('td.text2')[2].text
    self.location = clean_html(html.css('td.text2')[3])

    html.css('tr.zl11,tr.zl12').each do |line|
      agenda_item = self.agenda_items.build
      agenda_item.number = line.css('td.text4').text
      agenda_item.title = line.css('td')[3].text
      document_link = line.css('td[nowrap=nowrap] a')[1]
      if document_link
        allris_id = document_link['href']
        allris_id = allris_id[/VOLFDNR=(\d+)/, 1].to_i
        agenda_item.document = Document.find_by(allris_id: allris_id)
      end
    end

    self
  end

  def allris_url
    raise 'Allris ID missing' if allris_id.blank?

    "#{district.allris_base_url}/bi/to010.asp?SILFDNR=#{allris_id}"
  end
end
