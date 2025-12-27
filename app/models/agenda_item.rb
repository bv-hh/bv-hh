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
#  agenda_items_expr_idx               (((setweight(to_tsvector('german'::regconfig, (title)::text), 'A'::"char") || setweight(to_tsvector('german'::regconfig, minutes), 'B'::"char")))) USING gin
#  agenda_items_minutes_gin_trgm_idx   (minutes) USING gin
#  agenda_items_minutes_gist_trgm_idx  (minutes) USING gist
#  agenda_items_title_gin_trgm_idx     (title) USING gin
#  agenda_items_title_gist_trgm_idx    (title) USING gist
#  index_agenda_items_on_document_id   (document_id)
#  index_agenda_items_on_meeting_id    (meeting_id)
#
class AgendaItem < ApplicationRecord
  include Parsing
  include WithAttachments

  belongs_to :meeting
  belongs_to :document, optional: true
  has_one :district, through: :meeting

  scope :by_number, -> { order(number: :asc) }
  scope :by_meeting, -> { joins(:meeting).includes(:meeting).merge(Meeting.latest_first) }
  scope :logged, -> { where.not(allris_id: nil) }
  scope :with_minutes, -> { where.not(minutes: nil) }
  scope :incomplete, lambda {
    joins(:meeting).where.not(allris_id: nil)
                   .where('meetings.date <= ? AND meetings.date >= ?', 30.days.ago, 270.days.ago)
                   .where(minutes: nil, result: nil)
  }

  require 'open-uri'

  def retrieve_source
    return if allris_id.blank?

    Net::HTTP.get(URI(allris_url))
  end

  def retrieve_from_allris!(source = nil)
    return if allris_id.blank?

    source ||= retrieve_source

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))
    return if html.blank?

    html = html.css('table.risdeco').first
    return if html.blank?

    decision_text = html.css('td.text3')&.first&.text&.squish
    self.decision = decision_text unless decision_text == '(offen)'

    self.minutes = clean_html(html.xpath("//div[preceding-sibling::a[@name='allrisWP'] and following-sibling::a[@name='allrisBS']]")).presence
    self.result = extract_result(html)

    retrieve_attachments(html)
    save!
  end

  def extract_attachment_table(html)
    html.xpath("//table[preceding-sibling::a[@name='allrisBS'] and following-sibling::a[@name='allrisAE']]")
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

  def extract_result(html)
    clean_html(html.xpath("//div[preceding-sibling::a[@name='allrisAE']]")).presence ||
      clean_html(html.xpath("//div[preceding-sibling::a[@name='allrisBS']]")).presence
  end

  def as_json
    slice(:id, :meeting_id, :document_id, :title, :number, :decision).merge(minutes: strip_tags(minutes))
  end

  def self.minutes_prefix_search(term, root = nil)
    term = '' if term.nil?

    query = (root || AgendaItem.all).with_minutes.joins(:meeting)
    query = query.where('agenda_items.minutes ILIKE :term', term: "%#{term.downcase}%")

    query.order('meetings.date DESC')
  end
end
