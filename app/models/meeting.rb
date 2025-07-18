# frozen_string_literal: true

# == Schema Information
#
# Table name: meetings
#
#  id           :integer          not null, primary key
#  district_id  :integer
#  title        :string
#  date         :date
#  time         :string
#  room         :string
#  location     :string
#  allris_id    :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  committee_id :integer
#  start_time   :time
#  end_time     :time
#  note         :text
#
# Indexes
#
#  index_meetings_on_allris_id     (allris_id)
#  index_meetings_on_committee_id  (committee_id)
#  index_meetings_on_district_id   (district_id)
#

require 'net/http'

class Meeting < ApplicationRecord
  include Parsing
  include WithAttachments

  OBJECT_MOVED = 'Object moved'
  AUTH_REDIRECT = 'noauth.asp'

  belongs_to :district
  belongs_to :committee, optional: true

  has_many :agenda_items, dependent: :destroy

  scope :latest_first, -> { order(date: :desc) }
  scope :complete, -> { where.not(title: nil) }
  scope :with_agenda, -> { complete.joins(:agenda_items).distinct }
  scope :with_duration, -> { where.not(start_time: nil).where.not(end_time: nil) }
  scope :in_month, ->(date) { where(date: date.all_month) }
  scope :in_future, -> { where(date: Time.zone.today..) }
  scope :recent, -> { where(date: (7.days.ago..7.days.from_now)) }

  def retrieve_from_allris!(source = Net::HTTP.get(URI(allris_url)))
    return nil if source.include?(OBJECT_MOVED) || source.include?(AUTH_REDIRECT)

    html = Nokogiri::HTML.parse(source, nil, 'ISO-8859-1')

    self.title = html.css('h1').first&.text&.gsub('Tagesordnung -', '')&.squish

    html = html.css('table.risdeco').first

    retrieve_committee(html)
    retrieve_meta(html)
    save!

    retrieve_agenda_items(html)
    retrieve_attachments(html)
  end

  def extract_attachment_table(html)
    html.css('table.tk1').first
  end

  def retrieve_committee(html)
    committee_link = html.css('td.text1 a').first
    return if committee_link.nil?

    committee_href = committee_link['href']
    committee_allris_id = committee_href[/AULFDNR=(\d+)/, 1]
    committee_allris_id = committee_href[/PALFDNR=(\d+)/, 1] if committee_allris_id.nil?
    committee = district.committees.find_or_create_by(allris_id: committee_allris_id)
    committee.update!(name: clean_html(committee_link))
    self.committee = committee
  end

  def retrieve_meta(html)
    self.date = clean_html(html.css('td.text2').first)&.split(',')&.last&.squish
    self.start_time, self.end_time = retrieve_and_split_time(html)
    self.room = html.css('td.text2')[2]&.text
    self.location = clean_html(html.css('td.text2')[3])
    self.note = clean_html(html.css('td.text2')[4])
  end

  def retrieve_agenda_items(html)
    agenda_items.delete_all if date >= Time.zone.today

    html.css('tr.zl11,tr.zl12').each do |line|
      agenda_item = find_or_initialize_agenda_item(line)
      next if agenda_item.nil?

      agenda_item.save
      agenda_item.update_later! if agenda_item.allris_id.present?
    end
  end

  def find_or_initialize_agenda_item(line)
    number = line.css('td.text4').text
    return nil if number.blank?

    agenda_item = agenda_items.find_or_initialize_by(number:)
    agenda_item.allris_id = line.css('input[name=TOLFDNR]')&.first&.[](:value)
    agenda_item.title = line.css('td')[3].text
    document_link = line.css('td[nowrap=nowrap] a')[1]
    if document_link.present?
      allris_id = document_link['href']
      allris_id = allris_id[/VOLFDNR=(\d+)/, 1].to_i
      document = district.documents.find_or_create_by!(allris_id:)
      document.update_later! unless document.complete?
      agenda_item.document = document
    end

    agenda_item
  end

  def to_param
    "#{I18n.l(date).parameterize}-#{title.parameterize}-#{id}"
  end

  def allris_url
    raise 'Allris ID missing' if allris_id.blank?

    "#{district.allris_base_url}/bi/to010.asp?SILFDNR=#{allris_id}"
  end

  def update_later!
    UpdateMeetingJob.perform_later(self)
  end

  def duration
    end_time - start_time
  end

  def logged?
    agenda_items.logged.present?
  end

  def starts_at
    DateTime.new(date.year, date.month, date.day, start_time.hour, start_time.min, start_time.sec, start_time.zone)
  end

  def ends_at
    if end_time.present?
      DateTime.new(date.year, date.month, date.day, end_time.hour, end_time.min, end_time.sec, end_time.zone)
    elsif committee.average_duration.present?
      starts_at + committee.average_duration.seconds
    else
      starts_at + 4.hours
    end
  end

  private

  def retrieve_and_split_time(html)
    times = html.css('td.text2')[1].text.split('-')
    [times.first&.squish, times.last&.squish]
  end
end
