class CheckForUpdatesJob < ApplicationJob

  ALLRIS_UPDATES_URL = '/bi/vo040.asp'

  # OLDEST_ALLRIS_ID = 1007791 # 1.1.2019 HH-Nord
  OLDEST_ALLRIS_ID = 1010166

  def perform(district = nil)
    if district.nil?
      District.find_each do |district|
        CheckForUpdatesJob.perform_later(district)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    source = URI.open(district.allris_base_url + ALLRIS_UPDATES_URL, &:read)
    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

    latest_link = html.css('tr.zl12 a').first['href']
    current_allris_id = (latest_link[/VOLFDNR=(\d+)/, 1]).to_i

    latest_allris_id = [district.oldest_allris_id, district.documents.maximum(:allris_id) || 0].max

    while current_allris_id > latest_allris_id
      document = district.documents.find_or_create_by!(allris_id: current_allris_id)
      UpdateDocumentJob.perform_later(document)

      current_allris_id -= 1
    end

  end
end
