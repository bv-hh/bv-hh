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

  # Resolution order, most trustworthy first. Each step either answers or
  # declines; nothing guesses.
  #
  #   1. the official street register, exactly
  #   2. the OpenStreetMap POI gazetteer, exactly
  #   3. either register again, for a place just over the district border
  #   4. the street register again, through a trigram match, for OCR damage
  #
  # Google Places used to sit at the end and answer for anything, which is why
  # the blocklist had to exist. With it gone, an unknown name simply produces
  # no location.
  #
  # Every step is confined to the district, the reuse of an existing row
  # included. That last one is the whole point: many street names are also
  # ordinary German words, so the NER model proposes them everywhere. "Plan",
  # "Sand", "Heimat", "Schulweg", "Am Bahnhof", "Durchschnitt", "Bundesstraße"
  # are each a real street in exactly one district, and the register says which.
  # Reusing a row across districts threw that answer away and let whichever
  # district happened to mention the word first pin all seven — 1041 documents
  # on one point for "Plan" alone. A district that the register does not place
  # the street in now resolves nothing — unless the place is right on its
  # border, which step 3 is for.
  def self.determine_locations(extracted_name, district)
    return [] if blocked?(extracted_name)
    # Stadtteile are areas, recorded on the document as documents.quarters.
    # Geocoding one would put a point in the middle of it.
    return [] if Quarter.canonical_names([extracted_name]).any?

    locations = Location.normalized(extracted_name).where(district: district)
    return locations if locations.present?

    from_gazetteer(extracted_name, district).presence ||
      from_poi(extracted_name, district).presence ||
      from_nearby(extracted_name, district).presence ||
      from_fuzzy_gazetteer(extracted_name, district)
  end

  # Resolves a street name against the official Hamburg gazetteer, using its
  # registered coordinates directly. A name can occur in several districts, so
  # Street.for limits the answer to the district's own streets.
  def self.from_gazetteer(extracted_name, district)
    Street.for(extracted_name, district).map do |street|
      build_location(extracted_name, district, name: street.name, latitude: street.latitude,
                                               longitude: street.longitude, place_id: "gazetteer:#{street.street_key}",
                                               formatted_address: street.formatted_address)
    end
  end

  # Stations, reached only from TransitGazetteer, which has seen the "U/S" or
  # "Haltestelle" prefix in the text. The extracted name is recorded as the
  # prefixed form would not survive normalization, so the station's own name
  # stands in — a location named "Barmbek" here means the station, and the
  # Stadtteil path never creates one.
  def self.determine_station_locations(station_name, district)
    return [] if blocked?(station_name)

    Poi.transit_for(station_name, district).map do |poi|
      build_location(poi.name, district, name: poi.name, latitude: poi.latitude,
                                         longitude: poi.longitude, place_id: poi.place_key,
                                         formatted_address: poi.formatted_address)
    end
  end

  # Everything the street register does not name: parks, playgrounds, schools,
  # cemeteries, squares. The POI's district comes from the Quarter polygons at
  # import time, so a containment check here would ask a question already
  # answered — unlike the Google path, which needed one.
  def self.from_poi(extracted_name, district)
    Poi.for(extracted_name, district).map do |poi|
      build_location(extracted_name, district, name: poi.name, latitude: poi.latitude,
                                               longitude: poi.longitude, place_id: poi.place_key,
                                               formatted_address: poi.formatted_address)
    end
  end

  # A street or POI just outside the district, close enough to its border that
  # a document from it means the real place. Above the trigram match because a
  # real place 400 m away is a better answer than a corrected spelling, and
  # below both exact steps because a district's own register always wins.
  def self.from_nearby(extracted_name, district)
    nearby = Street.near_for(extracted_name, district).map do |street|
      build_location(extracted_name, district, name: street.name, latitude: street.latitude,
                                               longitude: street.longitude, place_id: "gazetteer:#{street.street_key}",
                                               formatted_address: street.formatted_address)
    end

    nearby.presence || Poi.near_for(extracted_name, district).map do |poi|
      build_location(extracted_name, district, name: poi.name, latitude: poi.latitude,
                                               longitude: poi.longitude, place_id: poi.place_key,
                                               formatted_address: poi.formatted_address)
    end
  end

  # Last, because a corrected name is a guess in a way the other two are not:
  # documents are OCR'd PDFs and "Lehnhartzstraße" is meant to be
  # "Lenhartzstraße". Street.fuzzy_for refuses ambiguous cases outright.
  def self.from_fuzzy_gazetteer(extracted_name, district)
    Street.fuzzy_for(extracted_name, district).map do |street|
      build_location(extracted_name, district, name: street.name, latitude: street.latitude,
                                               longitude: street.longitude, place_id: "gazetteer:#{street.street_key}",
                                               formatted_address: street.formatted_address)
    end
  end

  # One row per extracted name and resolved place. Two documents naming the
  # same street share it, and a name resolving to several places gets one each.
  def self.build_location(extracted_name, district, name:, latitude:, longitude:, place_id:, formatted_address:)
    find_or_create_by!(district: district, extracted_name: extracted_name, name: name) do |location|
      location.latitude = latitude
      location.longitude = longitude
      location.place_id = place_id
      location.formatted_address = formatted_address
      location.assign_attributes(place_attributes(name, latitude, longitude, district))
    end
  end

  # The denormalised place columns the feed and the Quarter pages query.
  #
  # The street register wins over the polygons wherever both apply: a street's
  # registered Quarter list covers the whole street, whereas its single
  # representative point would land in only one of the Quarters it crosses.
  #
  # Confined to the district, like every other register lookup. A street that
  # genuinely spans two districts is one register row carrying both, so the
  # union across the whole street survives; what does not is a *different*
  # street of the same name elsewhere, which would otherwise lend this row its
  # Quarters and put it on their pages.
  def self.place_attributes(name, latitude, longitude, district)
    streets = Street.for(name, district)
    covering = Quarter.covering(latitude, longitude)

    {
      street_name: streets.first&.normalized_name,
      quarters: quarters_for(streets, covering),
    }
  end

  def self.quarters_for(streets, covering)
    # A point outside every Quarter is not in Hamburg, whatever the register
    # says about a same-named street somewhere else — it must not show up on a
    # Quarter's map. Only legacy rows can reach this now that every source is a
    # local register whose points are inside Hamburg by construction, and
    # repair_coordinates! snaps the ones the street register can place.
    return [] if Quarter.boundaries? && covering.empty?

    streets.flat_map(&:quarters).uniq.presence || covering
  end

  # A district's bounds are a rectangle, and Hamburg's neighbours poke into it:
  # Norderstedt's streets sit inside Hamburg-Nord's bounding box, so geocoded
  # results from there used to be accepted and pinned on the wrong map. The
  # district's real outline, built from its Stadtteile, answers the same
  # question exactly. Fall back to the rectangle while the quarters table is
  # still empty, so a fresh install without an import does not reject
  # everything.
  #
  # Nothing in the resolution path is gated by this any more — every source is
  # a local register — but repair_coordinates! and the backfill task still ask
  # it of rows created before that was true.
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

  # Google used to answer a street name with the same-named street in a
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
