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
  # 'political' covered countries, states and whole districts — the vague end,
  # and the source of pins like "Innenstadt". 'sublocality' stays: it is what
  # names a real sub-area such as Jarrestadt or Karolinenviertel.
  VALID_TYPES = %w[park route sublocality]

  belongs_to :district

  has_many :document_locations, dependent: :destroy
  has_many :documents, through: :document_locations

  validates :name, presence: true
  validates :extracted_name, presence: true

  before_save :normalize_name

  # BLOCKED_LOCATIONS is the hand-written core; BlockedLocationName is the list
  # derived from the corpus and extended by editors. See LocationBlocklist.
  def self.blocked?(location)
    BLOCKED_LOCATIONS.include?(normalize(location)) || BlockedLocationName.blocked?(location)
  end

  def self.normalized(name)
    Location.where(normalized_name: normalize(name))
  end

  def self.normalize(name)
    name&.downcase&.strip
  end

  def self.determine_locations(extracted_name, district)
    return [] if blocked?(extracted_name)
    # Stadtteile are areas, recorded on the document as documents.quarters.
    # Geocoding one would put a point in the middle of it.
    return [] if Quarter.canonical_names([extracted_name]).any?

    locations = Location.normalized(extracted_name)
    return locations if locations.present?

    gazetteer_locations = from_gazetteer(extracted_name, district)
    return gazetteer_locations if gazetteer_locations.present?

    from_google(extracted_name, district)
  end

  def self.from_google(extracted_name, district)
    google_result = GoogleMaps.find_places(normalize(extracted_name), district)
    return [] if google_result.blank?

    google_result['candidates'].filter_map do |candidate|
      location = Location.find_by(district: district, place_id: candidate['place_id'])
      next location if location.present?

      latlng = candidate['geometry']['location']
      next if latlng.blank?
      next if Location.outside_district?(latlng['lat'], latlng['lng'], district)

      if candidate['types'].intersect?(VALID_TYPES)
        Location.create!(district: district, name: candidate['name'], extracted_name: extracted_name, place_id: candidate['place_id'],
                         latitude: latlng['lat'], longitude: latlng['lng'], formatted_address: candidate['formatted_address'],
                         **place_attributes(candidate['name'], latlng['lat'], latlng['lng']))
      end
    end
  end

  # Resolves a street name against the official Hamburg gazetteer, using its
  # registered coordinates directly (no Google Maps lookup). A name can occur in
  # several districts, so results are limited to the district's bounds.
  def self.from_gazetteer(extracted_name, district)
    Street.for(extracted_name, district).map do |street|
      find_or_create_by!(district: district, extracted_name: extracted_name, name: street.name) do |location|
        location.latitude = street.latitude
        location.longitude = street.longitude
        location.place_id = "gazetteer:#{street.street_key}"
        location.formatted_address = street.formatted_address
        location.assign_attributes(place_attributes(street.name, street.latitude, street.longitude))
      end
    end
  end

  # The denormalised place columns the feed and the Quarter pages query.
  #
  # The street register wins over the polygons wherever both apply: a street's
  # registered Quarter list covers the whole street, whereas its single
  # representative point would land in only one of the Quarters it crosses.
  # Street rows are looked up across ALL districts on purpose — Location.normalized
  # has no district filter, so one row is shared by every district that mentions
  # the name, and narrowing here would silently lose the others' documents.
  def self.place_attributes(name, latitude, longitude)
    streets = Street.where(normalized_name: Street.normalize(name))
    covering = Quarter.covering(latitude, longitude)

    {
      street_name: streets.first&.normalized_name,
      quarters: quarters_for(streets, covering),
    }
  end

  def self.quarters_for(streets, covering)
    # A point outside every Quarter is not in Hamburg, whatever the register
    # says about a same-named street somewhere else — it must not show up on a
    # Quarter's map. Only legacy rows can reach this now that from_google
    # rejects such candidates outright and repair_coordinates! snaps the ones
    # the register can place.
    return [] if Quarter.boundaries? && covering.empty?

    streets.flat_map(&:quarters).uniq.presence || covering
  end

  # A district's bounds are a rectangle, and Hamburg's neighbours poke into it:
  # Norderstedt's streets sit inside Hamburg-Nord's bounding box, so Google
  # results from there used to be accepted and pinned on the wrong map. The
  # district's real outline, built from its Stadtteile, answers the same
  # question exactly. Fall back to the rectangle while the quarters table is
  # still empty, so a fresh install without an import does not reject
  # everything.
  #
  # Only the Google fallback is gated by this. A street legitimately crossing a
  # district boundary comes from the gazetteer, which matches on the register's
  # own multi-district street keys and never reaches here.
  def self.outside_district?(latitude, longitude, district)
    return out_of_bounds?(latitude, longitude, district.bounds) unless Quarter.boundaries?

    !district.contains?(latitude, longitude)
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

  # Google sometimes answered a street name with the same-named street in a
  # neighbouring town — "Tarpenbekstraße, 22848 Norderstedt" instead of the
  # Hamburg one — because the old bounding-box check could not tell them apart.
  # Where the official register knows that street inside this location's own
  # district, its coordinates are authoritative, so snap to them.
  #
  # Deliberately narrow: only points that lie outside every Quarter are
  # touched, and only when the register match is within the same district. A
  # street name recurring across districts must not drag a correct location to a
  # different district's street of the same name.
  # Returns the repaired location, or nil when there was nothing to repair.
  def repair_coordinates!
    return nil if latitude.blank? || longitude.blank?
    return nil unless Quarter.boundaries?
    return nil if Quarter.covering(latitude, longitude).any?

    street = Street.for(name, district).first
    return nil if street.blank? || street.latitude.blank?

    update!(latitude: street.latitude, longitude: street.longitude,
            formatted_address: street.formatted_address, place_id: "gazetteer:#{street.street_key}")
    self
  end

  private

  def normalize_name
    self.normalized_name = Location.normalize(extracted_name)
  end
end
