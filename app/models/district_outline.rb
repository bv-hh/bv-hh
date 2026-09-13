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

  class << self
    # GeoJSON MultiPolygon coordinates, [polygon][ring][point][lng, lat] — the
    # same shape as Quarter#geometry, so the map draws both the same way.
    def for(district_number)
      return [] if district_number.blank?

      cache[district_number] ||= new(Quarter.in_district(district_number).to_a).polygons
    end

    # Drops the memoized outlines; called from Quarter.reset! after an import.
    def reset!
      @cache = nil
    end

    private

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
