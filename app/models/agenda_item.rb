# frozen_string_literal: true

# == Schema Information
#
# Table name: agenda_items
#
#  id          :bigint           not null, primary key
#  decision    :string
#  minutes     :text
#  number      :string
#  result      :text
#  title       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  allris_id   :integer
#  document_id :bigint
#  meeting_id  :bigint
#
# Indexes
#
#  index_agenda_items_on_document_id  (document_id)
#  index_agenda_items_on_meeting_id   (meeting_id)
#
class AgendaItem < ApplicationRecord
  include Parsing

  belongs_to :meeting
  belongs_to :document, optional: true
  has_one :district, through: :meeting
  has_many :attachments, as: :attachable, dependent: :destroy

  scope :by_number, -> { order(number: :asc) }
  scope :by_meeting, -> { joins(:meeting).includes(:meeting).merge(Meeting.latest_first) }
  scope :logged, -> { where.not(allris_id: nil) }
  scope :incomplete, lambda {
    joins(:meeting).where.not(allris_id: nil)
                   .where('meetings.date <= ? AND meetings.date >= ?', 30.days.ago, 270.days.ago)
                   .where(minutes: nil, result: nil)
  }

  require 'open-uri'

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

    retrieve_attachments(html)
    save!
  end

  def retrieve_attachments(html)
    attachment_table = html.xpath("//table[preceding-sibling::a[@name='allrisBS'] and following-sibling::a[@name='allrisAE']]")
    if attachment_table
      current_attachment_names = []
      attachment_table.css('a[title*="(Öffnet Dokument in neuem Fenster)"]').each do |attachment_link|
        href = attachment_link['href']
        uri = URI.parse(href)

        name = attachment_link.text
        current_attachment_names << name

        next if attachments.exists?(name:)

        filename = File.basename(uri.path)
        io = URI.parse("#{district.allris_base_url}/bi/#{href}").open

        attachment = attachments.create!(name:, district:)
        attachment.file.attach(io:, filename:)
        attachment.extract_later!
      end
    end
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
