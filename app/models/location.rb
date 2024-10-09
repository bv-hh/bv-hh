# frozen_string_literal: true

# == Schema Information
#
# Table name: locations
#
#  id              :bigint           not null, primary key
#  extracted_name  :string
#  latitude        :float
#  longitude       :float
#  name            :string
#  normalized_name :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  place_id        :string
#
# Indexes
#
#  index_locations_on_name             (name)
#  index_locations_on_normalized_name  (normalized_name)
#  index_locations_on_place_id         (place_id)
#
class Location < ApplicationRecord

  BLOCKED_LOCATIONS = %w(norderstedt hamburg straße) + District.all.map(&:name).map(&:downcase)

  has_many :document_locations, dependent: :destroy

  validates :name, presence: true
  validates :extracted_name, presence: true

  before_save :normalize_name

  def self.blocked?(location)
    BLOCKED_LOCATIONS.include?(location.downcase)
  end

  def self.normalized(name)
    Location.where(normalized_name: normalize(name))
  end

  def self.normalize(name)
    name&.downcase&.strip
  end

  def self.determine_locations(extracted_name)
    locations = Location.normalized(extracted_name)
    return locations if locations.present?

    google_result = GoogleMaps.find_place(extracted_name)
    return [] if google_result.blank?

    google_result['candidates'].filter_map do |candidate|
      next if Location.exists?(place_id: candidate['place_id'])

      if candidate['types'].include?('route')
        latlng = candidate['geometry']['location']
        Location.create!(name: candidate['name'], extracted_name: extracted_name, place_id: candidate['place_id'],
                         latitude: latlng['lat'], longitude: latlng['lng'])
      end
    end
  end

  private

  def normalize_name
    self.normalized_name = Location.normalize(self.extracted_name)
  end
end
