# frozen_string_literal: true

# Imports the 104 official Hamburg Quarters with their boundaries from the
# "ALKIS Verwaltungsgrenzen" WFS. Fetching (network) and parsing (pure) are
# separate so the parser can be tested against a fixture, exactly as in
# StreetImporter.
class QuarterImporter
  WFS_URL = 'https://geodienste.hamburg.de/HH_WFS_Verwaltungsgrenzen'
  TYPE_NAME = 'app:stadtteile'

  # Hamburg plus a generous margin. The sibling de.hh.up:* services ignore
  # srsName and answer in EPSG:25832 regardless, whose coordinates are in the
  # hundreds of thousands — so a bounds check is the cheap way to catch a
  # service that silently changed its mind about the projection.
  LAT_RANGE = (53.3..54.0)
  LNG_RANGE = (8.4..10.4)

  class WrongProjectionError < StandardError; end

  def self.import!
    new.import!
  end

  def import!
    now = Time.current
    rows = parse(fetch)
    raise WrongProjectionError, 'no features returned' if rows.empty?

    Quarter.transaction do
      Quarter.delete_all
      Quarter.insert_all(rows.map { |row| row.merge(created_at: now, updated_at: now) }) # rubocop:disable Rails/SkipsModelValidations
    end

    Quarter.reset!
    Rails.logger.info "QuarterImporter: imported #{rows.size} Quarters"
    rows.size
  end

  def fetch
    options = {
      service: 'WFS',
      version: '2.0.0',
      request: 'GetFeature',
      typeNames: TYPE_NAME,
      srsName: 'EPSG:4326',
      outputFormat: 'application/geo+json',
    }
    url = "#{WFS_URL}?#{URI.encode_www_form(options)}"

    client = HTTPClient.new
    # Use the system CA store; HTTPClient's bundled cacert is outdated and fails
    # to verify the geodienste.hamburg.de certificate chain.
    client.ssl_config.set_default_paths
    client.get_content(url)
  end

  # Parses an app:quarters GeoJSON FeatureCollection into rows ready for
  # Quarter.insert_all.
  def parse(geojson)
    collection = geojson.is_a?(String) ? JSON.parse(geojson) : geojson

    collection.fetch('features', []).filter_map { |feature| row_for(feature) }
  end

  private

  def row_for(feature)
    properties = feature['properties'] || {}
    name = properties['stadtteil_name'].to_s.squish
    return nil if name.blank?

    polygons = polygons_for(feature['geometry'])
    return nil if polygons.empty?

    {
      name: name,
      slug: name.parameterize,
      key: properties['stadtteil_schluessel'].to_s.squish,
      number: properties['stadtteil_nummer'].to_s.squish.presence,
      bezirk: properties['bezirk'].presence&.to_i,
      bezirk_name: properties['bezirk_name'].to_s.squish.presence,
      geometry: polygons,
    }.merge(bounding_box(polygons))
  end

  # Normalises Polygon and MultiPolygon to the MultiPolygon shape
  # [polygon][ring][point][lng, lat], and asserts the projection along the way.
  def polygons_for(geometry)
    return [] if geometry.blank?

    polygons =
      case geometry['type']
      when 'MultiPolygon' then geometry['coordinates']
      when 'Polygon' then [geometry['coordinates']]
      else []
      end

    polygons.map { |rings| rings.map { |ring| close(verify(ring)) } }
  end

  def verify(ring)
    ring.each do |longitude, latitude|
      next if LNG_RANGE.cover?(longitude) && LAT_RANGE.cover?(latitude)

      raise WrongProjectionError,
            "coordinate #{[longitude, latitude].inspect} is outside Hamburg — expected EPSG:4326 lon/lat"
    end
  end

  # Ray casting walks the ring with each_cons(2), so the ring has to be closed.
  # GeoJSON requires it, but a malformed export would silently lose one edge.
  def close(ring)
    ring.first == ring.last ? ring : ring + [ring.first]
  end

  def bounding_box(polygons)
    points = polygons.flatten(2)

    {
      min_lng: points.map(&:first).min,
      max_lng: points.map(&:first).max,
      min_lat: points.map(&:last).min,
      max_lat: points.map(&:last).max,
    }
  end
end
