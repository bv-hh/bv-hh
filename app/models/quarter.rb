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

  # About 7 to 11 metres, in degrees.
  SIMPLIFY_TOLERANCE = 0.0001
  # Cells per side of the grid searched for a label point.
  LABEL_GRID = 16

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

    # The Quarters sharing a stretch of boundary with +quarter+, district lines
    # notwithstanding. ALKIS draws adjacent Quarters from the same vertices, so
    # it is enough to look for points two rings have in common; a single shared
    # point is only corners touching.
    def touching(quarter)
      own = quarter.boundary_points

      all_cached.select do |other|
        other != quarter && other.boxes_touch?(quarter) && (other.boundary_points & own).size > 1
      end
    end

    # A district's Quarters by name, from the per-process cache, so what they
    # memoize (simplified_geometry, label_point) is worked out once.
    def cached_in_district(number)
      all_cached.select { |quarter| quarter.district_number == number }
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

  def neighbours
    self.class.touching(self)
  end

  # The boundary thinned for drawing a whole district at once: rounded like
  # DistrictOutline and simplified to within SIMPLIFY_TOLERANCE, which takes a
  # district's Stadtteile from 170 KB to about 12 KB. Same shape as geometry.
  # Neighbours are simplified separately, so a shared edge can part by a few
  # metres — invisible at the zoom that shows a whole district.
  def simplified_geometry
    @simplified_geometry ||= polygons.map do |rings|
      rings.map { |ring| simplify(ring.map { |lng, lat| [lng.round(5), lat.round(5)] }) }
    end
  end

  # Where a label on the map goes: [lng, lat, radius], the point of the
  # largest polygon farthest from its edges, and that distance in degrees of
  # latitude. A centroid can fall on a neighbour, or outside a crescent.
  # A grid search, then a finer one around the best cell, is close enough
  # for a label.
  def label_point
    @label_point ||= begin
      rings = simplified_geometry.max_by { |polygon| ring_box_area(polygon.first) }
      scale = Math.cos(rings.first.first.last * Math::PI / 180)
      best = farthest_inside(rings, label_candidates(rings.first), scale) || rings.first.first
      best = farthest_inside(rings, label_candidates(cell_around(best, rings.first)) + [best], scale)

      [best[0].round(5), best[1].round(5), edge_distance(rings, best, scale).round(5)]
    end
  end

  # Every vertex of every ring, rounded so that the same point read twice
  # compares equal. Memoized on the cached instances, like the polygons.
  def boundary_points
    @boundary_points ||= polygons.flatten(2).to_set { |lng, lat| [lng.round(6), lat.round(6)] }
  end

  # A cheap test before comparing vertices: whether the bounding boxes overlap
  # or meet. Without a box there is nothing to rule out.
  def boxes_touch?(other)
    return true if [min_lat, other.min_lat].any?(&:blank?)

    min_lat <= other.max_lat && other.min_lat <= max_lat && min_lng <= other.max_lng && other.min_lng <= max_lng
  end

  private

  # Douglas–Peucker: keep the point farthest from the line between the ends
  # if it strays more than the tolerance, and recurse on both halves.
  def simplify(points)
    return points if points.size < 3

    first = points.first
    last = points.last
    distances = points[1...-1].map { |point| segment_distance(point, first, last) }
    farthest = distances.each_with_index.max_by(&:first)
    return [first, last] if farthest.first <= SIMPLIFY_TOLERANCE

    index = farthest.last + 1
    simplify(points[..index])[...-1] + simplify(points[index..])
  end

  # Points of a grid over the box around +points+, inside the polygon or not.
  def label_candidates(points)
    (min_lng, max_lng), (min_lat, max_lat) = points.transpose.map(&:minmax)
    (0..LABEL_GRID).to_a.product((0..LABEL_GRID).to_a).map do |i, j|
      [min_lng + ((max_lng - min_lng) * i / LABEL_GRID), min_lat + ((max_lat - min_lat) * j / LABEL_GRID)]
    end
  end

  def farthest_inside(rings, points, scale)
    points.select { |lng, lat| point_in_polygon?(rings, lat, lng) }.max_by { |point| edge_distance(rings, point, scale) }
  end

  # How far a point is from the nearest edge of the polygon, in degrees of
  # latitude (longitude scaled by +scale+).
  def edge_distance(rings, (lng, lat), scale)
    point = [lng * scale, lat]
    rings.map do |ring|
      ring.each_cons(2).map { |(lng1, lat1), (lng2, lat2)| segment_distance(point, [lng1 * scale, lat1], [lng2 * scale, lat2]) }.min
    end.min
  end

  # The corners of one grid cell either side of +point+.
  def cell_around((lng, lat), ring)
    step = ring.map(&:first).minmax.reduce(:-).abs / LABEL_GRID
    [[lng - step, lat - step], [lng + step, lat + step]]
  end

  def ring_box_area(ring)
    ring.transpose.map { |values| values.minmax.reduce(:-).abs }.reduce(:*)
  end

  # In degrees, which is fine for comparing against a tolerance this small.
  def segment_distance((x, y), (x1, y1), (x2, y2))
    dx = x2 - x1
    dy = y2 - y1
    length = (dx * dx) + (dy * dy)
    t = length.zero? ? 0 : (((x - x1) * dx) + ((y - y1) * dy)).fdiv(length).clamp(0, 1)
    Math.hypot(x - (x1 + (t * dx)), y - (y1 + (t * dy)))
  end

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
