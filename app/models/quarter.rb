# frozen_string_literal: true

# == Schema Information
#
# Table name: quarters
#
#  id              :integer          not null, primary key
#  name            :string           not null
#  slug            :string           not null
#  key             :string           not null
#  number          :string
#  district_number :integer
#  district_name   :string
#  geometry        :jsonb            not null
#  min_lat         :float
#  max_lat         :float
#  min_lng         :float
#  max_lng         :float
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_quarters_on_district_number  (district_number)
#  index_quarters_on_key              (key) UNIQUE
#  index_quarters_on_name             (name)
#  index_quarters_on_slug             (slug) UNIQUE
#

# One of the 104 official Hamburg Quarters, imported from the "ALKIS
# Verwaltungsgrenzen" WFS. Holds the boundary as raw GeoJSON MultiPolygon
# coordinates (EPSG:4326, lon/lat pairs) so a Location can be assigned to the
# Quarters it falls into without PostGIS — see QuarterImporter.
#
# A Quarter belongs to exactly one district, which is what makes
# /hamburg-nord/langenhorn a canonical URL.
class Quarter < ApplicationRecord
  self.table_name = 'quarters'

  validates :name, presence: true
  validates :slug, presence: true
  validates :key, presence: true
  validates :geometry, presence: true

  scope :by_name, -> { order(:name) }
  scope :in_district, ->(number) { where(district_number: number) }

  class << self
    # Names of every Quarter containing the point. Normally one; two on a
    # shared boundary; none for a point outside Hamburg (or without coordinates).
    def covering(latitude, longitude)
      covering_quarters(latitude, longitude).map(&:name)
    end

    # The records behind +covering+, for callers that need more than the name —
    # District#contains? asks them which district the point is in.
    def covering_quarters(latitude, longitude)
      return [] if latitude.blank? || longitude.blank?

      all_cached.select { |quarter| quarter.contains?(latitude, longitude) }
    end

    # Whether boundaries have been imported at all. Callers use this to decide
    # whether covering? can be trusted, rather than reading an empty table as
    # "this point is nowhere".
    def boundaries?
      all_cached.any?
    end

    def lookup(slug)
      return nil if slug.blank?

      by_slug[slug.to_s.parameterize]
    end

    # Maps a user-supplied name to the register's own spelling, so that a
    # lowercase query param still matches the exactly-cased values stored in
    # locations.quarters.
    def canonical_names(names)
      index = all_cached.index_by { |quarter| quarter.name.downcase }

      Array(names).filter_map { |name| index[name.to_s.downcase.strip]&.name }.uniq
    end

    # Drops the memoized polygons; call after (re)importing.
    def reset!
      @all_cached = nil
      @by_slug = nil
      DistrictOutline.reset!
    end

    private

    def all_cached
      @all_cached ||= by_name.to_a
    end

    def by_slug
      @by_slug ||= all_cached.index_by(&:slug)
    end
  end

  def to_param
    slug
  end

  # The district this Quarter belongs to, as a District record.
  def district
    return nil if district_number.blank?

    District.by_number(district_number)
  end

  def contains?(latitude, longitude)
    return false unless within_bounds?(latitude, longitude)

    polygons.any? { |rings| point_in_polygon?(rings, latitude, longitude) }
  end

  private

  def within_bounds?(latitude, longitude)
    return true if min_lat.blank? # no precomputed box: fall through to the rings

    latitude.between?(min_lat, max_lat) && longitude.between?(min_lng, max_lng)
  end

  # GeoJSON MultiPolygon coordinates are [polygon][ring][point][lng, lat]; a
  # Polygon is normalised to a single-element list on import.
  def polygons
    geometry
  end

  # A point is inside a polygon when it is inside the exterior ring and not
  # inside any of its holes.
  def point_in_polygon?(rings, latitude, longitude)
    exterior, *holes = rings
    return false unless in_ring?(exterior, latitude, longitude)

    holes.none? { |hole| in_ring?(hole, latitude, longitude) }
  end

  # Ray casting: count how often a ray from the point crosses the ring's edges.
  def in_ring?(ring, latitude, longitude)
    inside = false

    ring.each_cons(2) do |(lng1, lat1), (lng2, lat2)|
      next unless (lat1 > latitude) != (lat2 > latitude)

      crossing_lng = ((lng2 - lng1) * (latitude - lat1) / (lat2 - lat1)) + lng1
      inside = !inside if longitude < crossing_lng
    end

    inside
  end
end
