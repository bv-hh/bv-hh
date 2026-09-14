# frozen_string_literal: true

# == Schema Information
#
# Table name: pois
#
#  id              :bigint           not null, primary key
#  category        :string           not null
#  district_number :integer
#  generic         :boolean          default(FALSE), not null
#  latitude        :float            not null
#  longitude       :float            not null
#  name            :string           not null
#  normalized_name :string           not null
#  osm_id          :bigint           not null
#  osm_type        :string           not null
#  postal_code     :string
#  quarter         :string
#  quarters        :string           default([]), not null, is an Array
#  transit         :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_pois_on_district_number      (district_number)
#  index_pois_on_normalized_name      (normalized_name)
#  index_pois_on_osm_type_and_osm_id  (osm_type,osm_id) UNIQUE
#  index_pois_on_quarters             (quarters) USING gin
#  index_pois_on_transit              (transit)
#

# A named point of interest in Hamburg, imported from OpenStreetMap — parks,
# playgrounds, schools, cemeteries, squares and the like.
#
# The third local gazetteer next to Street and Quarter, and the intended
# replacement for the Google Places fallback in Location.determine_locations.
# The difference in kind matters: Google is fuzzy text search that answers for
# anything, which is the root cause of pinned non-places like "Parkanlagen" and
# "BUKEA". A gazetteer matched on exact names simply finds nothing for those.
#
# Never queried at request time by the importer's doing — the table is filled by
# `rake pois:import` and read like any other local register.
class Poi < ApplicationRecord
  # Shorter names are noise once normalization has stripped punctuation, same
  # reasoning as StreetGazetteer::MIN_LENGTH.
  MIN_LENGTH = 4

  validates :name, presence: true
  validates :normalized_name, presence: true
  validates :category, presence: true

  before_validation :normalize_name

  # Pinnable by a bare name: neither too common to mean one place, nor a station
  # whose name only means a place when the text marks it as one.
  scope :pinnable, -> { where(generic: false, transit: false) }
  scope :transit, -> { where(transit: true) }
  scope :in_quarter, ->(name) { where('quarters @> ARRAY[?]::varchar[]', name.to_s) }

  # Spellings a document uses that OpenStreetMap does not. Hamburg features are
  # mapped with the city in the name — "Hamburger Stadtpark", "Stadtpark
  # Hamburg" — and no Drucksache writes it that way.
  CITY_QUALIFIERS = [/\Ahamburger /, /\Ahamburg /, / hamburg\z/].freeze

  # Normalization turns an apostrophe into a space, so OSM's "Ohlendorff'scher
  # Park" becomes "ohlendorff scher park" while a document writing
  # "Ohlendorffscher Park" becomes "ohlendorffscher park" — the same name, and
  # no match. 19 of the imported features carry one. Both typographic and
  # typewriter forms, since OSM uses either.
  APOSTROPHES = /['\u2018\u2019`´]/

  # POIs matching +name+ inside the district, mirroring Street.for. A district
  # without a known number gets nothing rather than everything. Matches the
  # register's own name or any of the spellings recorded for it.
  def self.for(name, district)
    number = district.number
    normalized = normalize(name)
    return none if number.blank? || normalized.blank?

    pinnable.where(district_number: number)
            .where('normalized_name = ? OR aliases @> ARRAY[?]::varchar[]', normalized, normalized)
  end

  # POIs of this name just outside the district but close to its border, the
  # counterpart of Street.near_for. Parks and green spaces straddle district
  # lines more often than streets do — the Niendorfer Gehege and the Stadtpark
  # are each written about from both sides.
  def self.near_for(name, district, metres: Street::NEAR_METRES)
    number = district.number
    normalized = normalize(name)
    return none if number.blank? || normalized.blank?

    candidates = pinnable.where.not(district_number: number)
                         .where('normalized_name = ? OR aliases @> ARRAY[?]::varchar[]', normalized, normalized)

    where(id: candidates.select { |poi| Street.near?(poi, number, metres) }.map(&:id))
  end

  # The spellings +name+ might appear as, minus the name itself. Too-short
  # results are dropped for the same reason MIN_LENGTH exists at all.
  def self.aliases_for(name)
    normalized = normalize(name)
    return [] if normalized.blank?

    spellings = [normalized, normalize(name.to_s.gsub(APOSTROPHES, ''))].uniq
    variants = spellings + spellings.flat_map { |spelling| without_city_qualifier(spelling) }

    variants.uniq.select { |variant| variant != normalized && variant.length >= MIN_LENGTH }
  end

  def self.without_city_qualifier(spelling)
    CITY_QUALIFIERS.filter_map do |qualifier|
      variant = spelling.sub(qualifier, '').strip
      variant if variant != spelling
    end
  end

  # Recomputes the alias lists in place, for when the rules change and a full
  # re-import would only fetch the same features again.
  def self.rebuild_aliases!
    changed = 0

    find_each do |poi|
      aliases = aliases_for(poi.name)
      next if aliases.sort == poi.aliases.sort

      poi.update_columns(aliases: aliases, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      changed += 1
    end

    changed
  end

  # Stations matching +name+ inside the district. Separate from .for on purpose:
  # only TransitGazetteer, which has seen the "U/S" or "Haltestelle" prefix in
  # the text, may ask for these.
  def self.transit_for(name, district)
    number = district.number
    normalized = normalize(name)
    return none if number.blank? || normalized.blank?

    transit.where(district_number: number)
           .where('normalized_name = ? OR aliases @> ARRAY[?]::varchar[]', normalized, normalized)
  end

  # The same rule as Street.normalize, deliberately: a name extracted from a
  # document is looked up in both gazetteers and must normalize identically in
  # either, or a hyphenated name would match one and miss the other.
  def self.normalize(name)
    Street.normalize(name)
  end

  # Names that are real words but cannot resolve to a point — either because
  # dozens of features in the same district carry them ("Spielplatz",
  # "Sportplatz", "Friedhof"), or because they are too short to be a signal.
  def self.generic_name?(name, occurrences: 1)
    normalized = normalize(name)
    return true if normalized.blank? || normalized.length < MIN_LENGTH
    return true if Quarter.canonical_names([name]).any?

    occurrences > PoiImporter::GENERIC_THRESHOLD
  end

  # Composed from OSM's own fields in the shape Street#formatted_address uses,
  # so a POI-resolved Location reads the same as a register-resolved one.
  def formatted_address
    locality = [postal_code, quarter].compact_blank.join(' ')
    [name, locality].compact_blank.join(', ')
  end

  # Stable identifier for locations.place_id, alongside "gazetteer:<street_key>".
  def place_key
    "osm:#{osm_type}/#{osm_id}"
  end

  private

  def normalize_name
    self.normalized_name = self.class.normalize(name)
  end
end
