# frozen_string_literal: true

class AgendaItem < ApplicationRecord
  include Parsing

  belongs_to :meeting
  belongs_to :document, optional: true
  has_one :district, through: :meeting

  scope :by_number, -> { order(number: :asc) }
  scope :by_meeting, -> { joins(:meeting).includes(:meeting).merge(Meeting.latest_first) }
  scope :logged, -> { where.not(allris_id: nil) }
  scope :incomplete, lambda {
    joins(:meeting).where.not(allris_id: nil)
                   .where('meetings.date <= ? AND meetings.date >= ?', 30.days.ago, 270.days.ago)
                   .where(minutes: nil, result: nil)
  }

  def retrieve_from_allris!(source = nil)
    return if allris_id.blank?

    source ||= Net::HTTP.get(URI(allris_url))

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))
    return if html.blank?

    html = html.css('table.risdeco').first

    decision_text = html.css('td.text3')&.first&.text&.squish
    self.decision = decision_text unless decision_text == '(offen)'

    self.minutes = clean_html(html.xpath("//div[preceding-sibling::a[@name='allrisWP'] and following-sibling::a[@name='allrisBS']]"))
    self.result = clean_html(html.xpath("//div[preceding-sibling::a[@name='allrisAE']]"))

    save!
  end

  def allris_url
    return nil if allris_id.blank?

    "#{meeting.district.allris_base_url}/bi/to020.asp?TOLFDNR=#{allris_id}"
  end

  def update_later!
    UpdateAgendaItemJob.perform_later(self)
  end

  def logged?
    Nokogiri::HTML.parse(minutes).text.present? || Nokogiri::HTML.parse(result).text.present?
  end
end
