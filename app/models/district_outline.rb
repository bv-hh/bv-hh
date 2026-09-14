# frozen_string_literal: true

# The outline of a district, dissolved from the boundaries of its Stadtteile.
#
# Districts have no geometry of their own — the geo register only knows
# Stadtteile (see Quarter) — but the ALKIS data is topologically clean: an edge
# between two neighbouring Stadtteile appears in both of their rings, with the
# same two points. So the union is the set of edges that appear exactly once,
# stitched back into rings. No PostGIS, no polygon clipping.
class DistrictOutline
  # Roughly a metre. The outline is only ever drawn on a map, and full ALKIS
  # precision would triple the size of the response.
  PRECISION = 5

  # One degree of latitude, and of longitude at the equator. Hamburg spans a
  # fiftieth of a degree, so treating the outline as flat over that span and
  # scaling longitude by cos(latitude) is accurate to well under a metre —
  # far inside what this is asked to distinguish.
  METRES_PER_DEGREE = 111_320.0

  class << self
    # GeoJSON MultiPolygon coordinates, [polygon][ring][point][lng, lat] — the
    # same shape as Quarter#geometry, so the map draws both the same way.
    def for(district_number)
      return [] if district_number.blank?

      cache[district_number] ||= new(Quarter.in_district(district_number).to_a).polygons
    end

    # Metres from a point to the district's border, 0 for a point on it. This is
    # distance to the *border*, not to the district: a point deep inside is far
    # from it too. Its caller only ever asks about points outside, where the two
    # readings agree — see Street.near_for.
    #
    # Distance to the nearest *segment*, not the nearest vertex: ALKIS puts a
    # vertex only where the border changes direction, so a point opposite the
    # middle of a long straight stretch has no vertex anywhere near it.
    def distance_to(district_number, latitude, longitude)
      return Float::INFINITY if latitude.blank? || longitude.blank?

      rings = self.for(district_number).flatten(1)
      return Float::INFINITY if rings.empty?

      scale = Math.cos(latitude * Math::PI / 180)
      rings.filter_map { |ring| nearest_on_ring(ring, latitude, longitude, scale) }.min || Float::INFINITY
    end

    # Drops the memoized outlines; called from Quarter.reset! after an import.
    def reset!
      @cache = nil
    end

    private

    def nearest_on_ring(ring, latitude, longitude, scale)
      ring.each_cons(2).map do |(lng1, lat1), (lng2, lat2)|
        nearest_on_segment(latitude, longitude, [lat1, lng1], [lat2, lng2], scale)
      end.min
    end

    # Distance to a line segment, in the flat projection: the foot of the
    # perpendicular where it falls between the endpoints, and the nearer
    # endpoint where it does not.
    def nearest_on_segment(latitude, longitude, from, to, scale)
      x = (longitude - from.last) * scale
      y = latitude - from.first
      dx = (to.last - from.last) * scale
      dy = to.first - from.first

      length = (dx * dx) + (dy * dy)
      along = length.zero? ? 0.0 : (((x * dx) + (y * dy)) / length).clamp(0.0, 1.0)

      Math.hypot(x - (along * dx), y - (along * dy)) * METRES_PER_DEGREE
    end

    def cache
      @cache ||= {}
    end
  end

  def initialize(quarters)
    @quarters = quarters
  end

  def polygons
    group(stitch(boundary_edges))
  end

  private

  attr_reader :quarters

  # Every edge of every Stadtteil ring, directed, keyed by the unordered pair of
  # its endpoints. A pair seen twice is an internal border between two
  # Stadtteile of this district and drops out of the union.
  def boundary_edges
    edges = Hash.new { |hash, key| hash[key] = [] }

    quarters.each do |quarter|
      quarter.geometry.each do |polygon|
        polygon.each do |ring|
          ring.each_cons(2) { |from, to| edges[[from, to].sort] << [from, to] }
        end
      end
    end

    edges.values.select(&:one?).flatten(1)
  end

  # Walks the remaining edges into closed rings. Each point has as many
  # outgoing as incoming boundary edges, so following any of them always
  # returns to the start.
  def stitch(edges)
    outgoing = Hash.new { |hash, key| hash[key] = [] }
    edges.each { |from, to| outgoing[from] << to }

    rings = []

    outgoing.each_key do |start|
      rings << walk(outgoing, start) while outgoing[start].any?
    end

    rings
  end

  def walk(outgoing, start)
    ring = [start]
    point = start

    while (following = outgoing[point].shift)
      ring << following
      break if following == start

      point = following
    end

    ring.map { |lng, lat| [lng.round(PRECISION), lat.round(PRECISION)] }
  end

  # A ring inside another one is a hole in it — an enclave, or the water inside
  # a harbour basin. Everything else is a polygon of its own: districts are not
  # always contiguous (Neuwerk belongs to Hamburg-Mitte).
  def group(rings)
    exteriors, holes = rings.partition { |ring| rings.none? { |other| !other.equal?(ring) && inside?(ring, other) } }

    exteriors.map do |exterior|
      [exterior, *holes.select { |hole| inside?(hole, exterior) }]
    end
  end

  def inside?(ring, other)
    point_in_ring?(other, ring.first)
  end

  # Ray casting, as in Quarter#in_ring?, but on [lng, lat] pairs throughout.
  def point_in_ring?(ring, point)
    longitude, latitude = point
    inside = false

    ring.each_cons(2) do |(lng1, lat1), (lng2, lat2)|
      next unless (lat1 > latitude) != (lat2 > latitude)

      crossing_lng = ((lng2 - lng1) * (latitude - lat1) / (lat2 - lat1)) + lng1
      inside = !inside if longitude < crossing_lng
    end

    inside
  end
end
