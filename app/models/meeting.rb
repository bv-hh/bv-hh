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

  has_one_attached :minutes_pdf

  scope :latest_first, -> { order(date: :desc) }
  scope :complete, -> { where.not(title: nil) }
  scope :with_agenda, -> { complete.joins(:agenda_items).distinct }
  scope :with_duration, -> { where.not(start_time: nil).where.not(end_time: nil) }
  scope :with_minutes, -> { where(id: AgendaItem.with_minutes.select(:meeting_id)) }
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
    allris_type = 'au'
    if committee_allris_id.nil?
      committee_allris_id = committee_href[/PALFDNR=(\d+)/, 1]
      allris_type = 'pa'
    end
    committee = district.committees.find_or_create_by(allris_id: committee_allris_id)
    committee.update!(name: clean_html(committee_link), allris_type:)
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

  def attach_minutes_later!
    AttachMeetingMinutesJob.perform_later(self)
  end

  # Downloads the public protocol PDF ("Niederschrift öffent. Teil") linked from
  # the agenda page and attaches it. ALLRIS gates the download behind a session
  # cookie and a one-time redirect, so we cannot use a plain Net::HTTP.get here.
  def retrieve_minutes_from_allris!
    return if allris_id.blank?

    pdf = download_minutes_pdf
    return if pdf.blank?

    minutes_pdf.attach(io: StringIO.new(pdf), filename: "niederschrift-#{allris_id}.pdf", content_type: 'application/pdf')
  end

  def duration
    end_time - start_time
  end

  # Total number of words recorded across all agenda items of this meeting.
  # A rough proxy for how much was discussed ("how much talking").
  def word_count
    agenda_items.sum(&:word_count)
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

  def download_minutes_pdf
    base = URI(district.allris_base_url)
    Net::HTTP.start(base.host, base.port, use_ssl: base.scheme == 'https') do |http|
      agenda = http.get("/bi/to010.asp?SILFDNR=#{allris_id}")
      params = agenda.body.include?(AUTH_REDIRECT) ? nil : minutes_download_params(agenda.body)
      next if params.blank?

      cookie = agenda['set-cookie']&.split(';')&.first
      fetch_minutes_pdf(http, params, cookie)
    end
  end

  def fetch_minutes_pdf(http, params, cookie)
    redirect = http.post('/bi/do027.asp', params, 'Cookie' => cookie, 'Content-Type' => 'application/x-www-form-urlencoded')
    location = redirect['location'].presence || redirect.body[/href="([^"]+)"/i, 1]
    return if location.blank?

    pdf = http.get("/bi/#{location}", 'Cookie' => cookie)
    pdf.body if pdf.body.start_with?('%PDF')
  end

  # Extracts the POST body for the public Niederschrift download form on the
  # agenda page, e.g. "DOLFDNR=1392414&options=64". Returns nil when the meeting
  # has no public protocol yet.
  def minutes_download_params(source)
    html = Nokogiri::HTML.parse(source, nil, 'ISO-8859-1')

    form = html.css('form[action="do027.asp"]').find do |candidate|
      button = candidate.at_css('input[type="submit"]')
      label = "#{button&.[]('value')} #{button&.[]('title')}"
      label.include?('Niederschrift') && label.match?(/öffent/i)
    end
    return if form.nil?

    dolfdnr = form.at_css('input[name="DOLFDNR"]')&.[]('value')
    return if dolfdnr.blank?

    params = { 'DOLFDNR' => dolfdnr }
    options = form.at_css('input[name="options"]')&.[]('value')
    params['options'] = options if options.present?
    URI.encode_www_form(params)
  end

  def retrieve_and_split_time(html)
    times = html.css('td.text2')[1].text.split('-')
    [times.first&.squish, times.last&.squish]
  end
end
