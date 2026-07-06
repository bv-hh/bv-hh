# frozen_string_literal: true

# == Schema Information
#
# Table name: parties
#
#  id          :integer          not null, primary key
#  allris_id   :integer
#  district_id :integer
#  name        :string
#  inactive    :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_parties_on_district_id                (district_id)
#  index_parties_on_district_id_and_allris_id  (district_id,allris_id) UNIQUE
#

require 'net/http'

class Party < ApplicationRecord
  include Parsing

  OBJECT_MOVED = 'Object moved'
  AUTH_REDIRECT = 'noauth.asp'

  END_DATE_DESIGNATION = 'Endedatum'

  belongs_to :district
  has_many :members, dependent: :nullify

  scope :active, -> { where(inactive: false) }
  scope :by_name, -> { order(:name) }

  def allris_url
    raise 'Allris ID missing' if allris_id.blank?

    "#{district.allris_base_url}/bi/fr020.asp?FRLFDNR=#{allris_id}"
  end

  def to_param
    "#{name.parameterize}-#{id}"
  end

  # fr020 is the single source of truth for a party's members.
  def retrieve_from_allris!(source = Net::HTTP.get(URI(allris_url)))
    return if source.include?(OBJECT_MOVED) || source.include?(AUTH_REDIRECT)

    html = Nokogiri::HTML.parse(source.force_encoding('ISO-8859-1'))
    self.name = html.css('h1').first&.text&.squish.presence || name

    if expired?(html)
      update!(inactive: true)
      members.update_all(inactive: true) # soft-delete: keep records, just hide
      return
    end

    update!(inactive: false)
    retrieve_members(html)
  end

  private

  def expired?(html)
    marker = html.css('h3.mark3').first&.text
    marker.present? && marker.include?(END_DATE_DESIGNATION)
  end

  def retrieve_members(html)
    table = html.css('table.tl1').find { |t| t.css('a[href*="kp020"]').any? }
    return if table.nil?

    seen_member_ids = []

    table.css('tr.zl11, tr.zl12').each do |row|
      member = retrieve_member(row)
      next if member.nil?

      seen_member_ids << member.id
    end

    # Members no longer listed left the party: hide them, but never destroy.
    members.where.not(id: seen_member_ids).update_all(inactive: true)
  end

  def retrieve_member(row)
    link = row.css('a[href*="kp020"]').first
    return nil if link.nil?

    member_allris_id = link['href'][/KPLFDNR=(\d+)/, 1]
    return nil if member_allris_id.blank?

    name = link.text.squish
    return nil if name.blank? # e.g. co-opted citizens whose name is withheld

    member = district.members.find_or_initialize_by(allris_id: member_allris_id)
    member.party = self
    member.name = name
    member.kind = row.css('td.text1').text.squish
    member.inactive = false
    member.save!

    member
  end
end
