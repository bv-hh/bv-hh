# frozen_string_literal: true

class Group < ApplicationRecord

  belongs_to :district

  has_many :members, dependent: :nullify

  scope :active, -> { where(expired_at: nil) }

  def retrieve_from_allris!(source = Net::HTTP.get(URI(allris_url)))
    html = Nokogiri::HTML.parse(source, nil, 'ISO-8859-1')

    expired = html.css('h3.mark3').first&.text
    if expired.present? && expired.include?('Endedatum')
      self.expired_at = expired.gsub('Endedatum:', '').squish
      save! and return
    end

    self.name = html.css('h1').first&.text&.squish

    save!

    retrieve_members(html)
  end

  def retrieve_members(html)
    html.css('tr.zl11,tr.zl12').each do |line|
      link = line.css('a').first
      next if link.blank?
      member_allris_id = link['href'][/KPLFDNR=(\d+)/, 1].to_i
      member = members.find_or_initialize_by(allris_id: member_allris_id)
      member.name = link.text.squish
      member.kind = line.css('td.text1').text
      member.save!
    end

    nil
  end

  def allris_url
    return nil if allris_id.blank?

    "#{district.allris_base_url}/bi/fr020.asp?FRLFDNR=#{allris_id}"
  end

  def html
    source = Net::HTTP.get(URI(allris_url))
    Nokogiri::HTML.parse(source, nil, 'ISO-8859-1')
  end

end
