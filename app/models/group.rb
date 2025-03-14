# frozen_string_literal: true

# == Schema Information
#
# Table name: groups
#
#  id          :bigint           not null, primary key
#  address     :text
#  email       :string
#  expired_at  :date
#  fax         :string
#  name        :string
#  phone       :string
#  www         :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  allris_id   :integer
#  district_id :bigint
#
# Indexes
#
#  index_groups_on_district_id  (district_id)
#
class Group < ApplicationRecord
  include Parsing

  belongs_to :district

  has_many :members, dependent: :nullify

  scope :active, -> { where(expired_at: nil) }

  def to_param
    "#{name.parameterize}-#{id}"
  end

  def retrieve_from_allris!(source = get_source)
    html = parsed_source(source)

    expired = html.css('h3.mark3').first&.text
    if expired.present? && expired.include?('Endedatum')
      self.expired_at = expired.gsub('Endedatum:', '').squish
      save! and return
    end

    details_html = html.xpath("//table[preceding-sibling::h3[text() = 'Anschrift']]").first
    retrieve_details(details_html) if details_html.present?

    self.name = html.css('h1').first&.text&.squish

    save!

    retrieve_members(html)
  end

  def retrieve_details(html)
    address_html = html.xpath(".//tr[not(descendant::*[@class='lb1'])]")
    self.address = address_html.map{ it.try(:text)&.squish }.compact_blank.join("\n") if address_html.present?

    self.phone = extract_contact_detail(html, 'telefon.gif')
    self.fax = extract_contact_detail(html, 'telefax.gif')
    self.email = extract_contact_detail(html, 'email.gif')
    self.www = extract_contact_detail(html, 'www.gif')
  end

  def retrieve_members(html)
    html.css('tr.zl11,tr.zl12').each do |line|
      link = line.css('a').first
      next if link.blank?
      member_allris_id = link['href'][/KPLFDNR=(\d+)/, 1].to_i
      member = members.find_or_initialize_by(allris_id: member_allris_id)
      member.name = link.text.squish
      next if member.name.blank?
      member.kind = line.css('td.text1').text
      member.save!
    end

    nil
  end

  def allris_url
    return nil if allris_id.blank?

    "#{district.allris_base_url}/bi/fr020.asp?FRLFDNR=#{allris_id}"
  end

  private

  def extract_contact_detail(html, identifier)
    html.xpath(".//td[preceding-sibling::td[descendant::img[contains(@src, '#{identifier}')]]]").text
  end

end
