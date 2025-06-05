# frozen_string_literal: true

# == Schema Information
#
# Table name: locations
#
#  id                :integer          not null, primary key
#  name              :string
#  place_id          :string
#  latitude          :float
#  longitude         :float
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  normalized_name   :string
#  extracted_name    :string
#  district_id       :integer
#  formatted_address :string
#
# Indexes
#
#  index_locations_on_district_id      (district_id)
#  index_locations_on_name             (name)
#  index_locations_on_normalized_name  (normalized_name)
#  index_locations_on_place_id         (place_id)
#

class Location < ApplicationRecord
  BLOCKED_LOCATIONS = %w[deutschland norderstedt hamburg hamburgs straße] +
                      District.all.map { |d| [d.name.downcase, "bezirk #{d.name.downcase}"] }.flatten + ['hamburg nord', 'hamburg mitte']
  VALID_TYPES = %w[park route political sublocality]

  belongs_to :district

  has_many :document_locations, dependent: :destroy
  has_many :documents, through: :document_locations

  validates :name, presence: true
  validates :extracted_name, presence: true

  before_save :normalize_name

  def self.blocked?(location)
    BLOCKED_LOCATIONS.include?(normalize(location))
  end

  def self.normalized(name)
    Location.where(normalized_name: normalize(name))
  end

  def self.normalize(name)
    name&.downcase&.strip
  end

  def self.determine_locations(extracted_name, district)
    return [] if blocked?(extracted_name)

    locations = Location.normalized(extracted_name)
    return locations if locations.present?

    google_result = GoogleMaps.find_places(normalize(extracted_name), district)
    return [] if google_result.blank?

    google_result['candidates'].filter_map do |candidate|
      location = Location.find_by(district: district, place_id: candidate['place_id'])
      next location if location.present?

      latlng = candidate['geometry']['location']
      next if latlng.blank?
      next if Location.out_of_bounds?(latlng['lat'], latlng['lng'], district.bounds)

      if candidate['types'].intersect?(VALID_TYPES)
        Location.create!(district: district, name: candidate['name'], extracted_name: extracted_name, place_id: candidate['place_id'],
                         latitude: latlng['lat'], longitude: latlng['lng'], formatted_address: candidate['formatted_address'])
      end
    end
  end

  # Bounds is an array with two arrays each with lat lng as elements, indicating northeast and southwest corner of a bounding box
  def self.out_of_bounds?(latitude, longitude, bounds)
    ne = bounds.first
    sw = bounds.last

    latitude > ne.first || latitude < sw.first || longitude > ne.last || longitude < sw.last
  end

  def to_param
    "#{name.parameterize}-#{id}"
  end

  private

  def normalize_name
    self.normalized_name = Location.normalize(extracted_name)
  end
end
