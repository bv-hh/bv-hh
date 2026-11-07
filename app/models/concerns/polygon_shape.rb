# frozen_string_literal: true

# Map helpers for anything with GeoJSON MultiPolygon coordinates in
# +polygons+ ([polygon][ring][point][lng, lat]): a Quarter's boundary, a
# District's outline. Results are memoized on the instance, so callers keep
# the instances around (Quarter.cached_in_district, District.by_number).
module PolygonShape
  # About 7 to 11 metres, in degrees.
  SIMPLIFY_TOLERANCE = 0.0001
  # Cells per side of the grid searched for a label point.
  LABEL_GRID = 16

  # The boundary thinned for a map of many shapes at once: rounded like
  # DistrictOutline and simplified to within SIMPLIFY_TOLERANCE, which takes a
  # district's Stadtteile from 170 KB to about 12 KB. Same shape as polygons.
  # Neighbours are simplified separately, so a shared edge can part by a few
  # metres — invisible at the zoom that shows them all.
  def simplified_geometry
    @simplified_geometry ||= polygons.map do |rings|
      rings.map { |ring| simplify(ring.map { |lng, lat| [lng.round(5), lat.round(5)] }) }
    end
  end

  # Where a label on the map goes: [lng, lat, radius], the point of the
  # largest polygon farthest from its edges, and that distance in degrees of
  # latitude. A centroid can fall on a neighbour, or outside a crescent.
  # A grid search, then a finer one around the best cell, is close enough
  # for a label. nil without a shape, or for one too thin for any grid point
  # to fall inside it, which is too thin to carry a label anyway.
  def label_point
    return @label_point if defined?(@label_point)

    @label_point = (find_label_point if simplified_geometry.any?)
  end

  private

  def find_label_point
    rings = simplified_geometry.max_by { |polygon| ring_box_area(polygon.first) }
    scale = Math.cos(rings.first.first.last * Math::PI / 180)
    coarse = farthest_inside(rings, label_candidates(rings.first), scale)
    return nil if coarse.nil?

    # coarse is inside, so the finer search always has a candidate.
    best = farthest_inside(rings, label_candidates(cell_around(coarse, rings.first)) + [coarse], scale)
    [best[0].round(5), best[1].round(5), edge_distance(rings, best, scale).round(5)]
  end

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
    lng_step, lat_step = ring.transpose.map { |values| values.minmax.reduce(:-).abs / LABEL_GRID }
    [[lng - lng_step, lat - lat_step], [lng + lng_step, lat + lat_step]]
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
