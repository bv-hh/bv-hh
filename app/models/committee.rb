# frozen_string_literal: true

# == Schema Information
#
# Table name: committees
#
#  id               :bigint           not null, primary key
#  average_duration :integer
#  inactive         :boolean          default(FALSE)
#  name             :string
#  order            :integer          default(0)
#  public           :boolean          default(TRUE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  allris_id        :integer
#  district_id      :bigint
#
# Indexes
#
#  index_committees_on_allris_id    (allris_id)
#  index_committees_on_district_id  (district_id)
#
require 'net/http'

class Committee < ApplicationRecord
  include Parsing

  LOCAL_COMMITTEE_DESIGNATION = 'Regionalausschuss'

  OBJECT_MOVED = 'Object moved'
  AUTH_REDIRECT = 'noauth.asp'

  belongs_to :district
  has_many :meetings, dependent: :nullify

  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships

  scope :open, -> { where(public: true) }
  scope :active, -> { where(inactive: false) }
  scope :by_order, -> { order(:order) }

  def update_average_duration!
    total_duration = 0
    meetings.with_duration.find_each do |meeting|
      total_duration += meeting.duration
    end

    self.average_duration = (total_duration.to_f / meetings.with_duration.count).round

    save!
  end

  def allris_members_url
    raise 'Allris ID missing' if allris_id.blank?

    if allris_type == 'pa'
      "#{district.allris_base_url}/bi/pa020.asp?PALFDNR=#{allris_id}"
    else
      "#{district.allris_base_url}/bi/au020.asp?AULFDNR=#{allris_id}"
    end
  end

  def retrieve_members_from_allris!(source = Net::HTTP.get(URI(allris_members_url)))
    return if source.include?(OBJECT_MOVED) || source.include?(AUTH_REDIRECT)

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))
    table = html.css('table.tl1').find { |t| t.css('a[href*="kp020"]').any? }
    return if table.nil?

    seen_member_ids = []

    table.css('tr.zl11, tr.zl12').each do |row|
      member = retrieve_member(row)
      next if member.nil?

      seen_member_ids << member.id
    end

    memberships.where.not(member_id: seen_member_ids).destroy_all
  end

  def local?
    name.include?(LOCAL_COMMITTEE_DESIGNATION)
  end

  def area
    return nil unless local?

    name.gsub(LOCAL_COMMITTEE_DESIGNATION, '')&.strip
  end

  def matches_area?(location_name)
    return false unless local?
    return false if location_name.blank?

    normalized_location_name = location_name.gsub(/[^\w ]/, '').downcase
    area&.gsub(/[^\w ]/, '')&.downcase == normalized_location_name
  end

  private

  def retrieve_member(row)
    link = row.css('a[href*="kp020"]').first
    return nil if link.nil?

    member_allris_id = link['href'][/KPLFDNR=(\d+)/, 1]
    return nil if member_allris_id.blank?

    name = link.text.squish
    return nil if name.blank? # e.g. co-opted citizens whose name is withheld

    # The party page (fr020) is the source of truth for members and their party;
    # here we only ensure the member exists so the committee roster is complete.
    member = district.members.find_or_create_by!(allris_id: member_allris_id) do |m|
      m.name = name
    end

    membership = memberships.find_or_initialize_by(member:)
    membership.update!(role: row.css('td.text1').text.squish)

    member
  end
end
