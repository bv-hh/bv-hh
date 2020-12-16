# frozen_string_literal: true

require 'open-uri'

class District < ApplicationRecord
  ALLRIS_DOCUMENT_UPDATES_URL = '/bi/vo040.asp'
  ALLRIS_MEETING_UPDATES_URL = '/bi/si010_e.asp' # ?MM=12&YY=2020

  # OLDEST_ALLRIS_ID = 1007791 # 1.1.2019 HH-Nord

  has_many :documents, dependent: :destroy
  has_many :meetings, dependent: :destroy

  validates :name, presence: true
  validates :allris_base_url, presence: true

  scope :by_name, -> { order(:name) }

  def to_param
    name.parameterize
  end

  def self.lookup(path)
    @districts ||= District.all.index_by { |d| d.name.parameterize; }

    @districts[path.parameterize]
  end

  def check_for_document_updates
    source = Net::HTTP.get(URI(allris_base_url + ALLRIS_DOCUMENT_UPDATES_URL))
    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

    latest_link = html.css('tr.zl12 a').first['href']
    current_allris_id = (latest_link[/VOLFDNR=(\d+)/, 1]).to_i

    latest_allris_id = [oldest_allris_document_id, documents.maximum(:allris_id) || 0].max

    while current_allris_id > latest_allris_id
      document = documents.find_or_create_by!(allris_id: current_allris_id)
      UpdateDocumentJob.perform_later(document)

      current_allris_id -= 1
    end
  end

  def check_for_meeting_updates # rubocop:disable Metrics/AbcSize
    oldest_meeting_date = [oldest_allris_meeting_date, meetings.maximum(:date) || 10.years.ago].max

    current_date = (Time.zone.now + 1.month).beginning_of_month

    while current_date >= oldest_meeting_date
      source = Net::HTTP.get(URI(allris_base_url + ALLRIS_MEETING_UPDATES_URL + "?MM=#{current_date.month}&YY=#{current_date.year}"))
      html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))

      html.css('tr.zl12 a,tr.zl11 a,tr.zl16 a,tr.zl17 a').each do |link|
        allris_id = (link['href'][/SILFDNR=(\d+)/, 1]).to_i
        meeting = meetings.find_or_create_by!(allris_id: allris_id)

        UpdateMeetingJob.perform_later(meeting)
      end

      current_date -= 1.month
    end
  end
end
