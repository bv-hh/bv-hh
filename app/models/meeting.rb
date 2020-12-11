
class Meeting < ApplicationRecord
  belongs_to :district

  has_many :agenda_items

  validates :district, presence: true

  def retrieve_from_allris
    source = URI.open(allris_url, &:read)

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

    full_title = html.css('h1').first&.text&.gsub('Tagesordnung -', '')&.squish
    self.title = full_title.split('Bitte beachten Sie:').first.squish

    html = html.css('table.risdeco').first

    self.committee = clean_html(html.css('td.text1')[1])
    self.date = clean_html(html.css('td.text2').first)&.split(',')&.last&.squish
    self.time = clean_html(html.css('td.text2')[1])
    self.room = clean_html(html.css('td.text2')[2])
    self.location = clean_html(html.css('td.text2')[3])

    html.css('tr.zl11,tr.zl12').each do |line|
      agenda_item = self.agenda_items.build
      agenda_item.number = clean_html(line.css('td.text4'))
      agenda_item.title = clean_html(line.css('td')[3])
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
