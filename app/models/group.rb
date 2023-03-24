# frozen_string_literal: true

class Group < ApplicationRecord

  belongs_to :district

  has_many :members, dependent: :nullify

  scope :active, -> { where(expired_at: nil) }

  def retrieve_from_allris!(source = Net::HTTP.get(URI(allris_url)))
    html = Nokogiri::HTML.parse(source, nil, 'ISO-8859-1')

    expired = html.css('h3.mark3').first&.text
    if expired.present? && expired.include?('Enddatum')
      self.expired_at = expired.gsub('Enddatum:', '').strip
      save! and return
    end

    self.name = html.css('h1').first&.text&.strip

    save!
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
