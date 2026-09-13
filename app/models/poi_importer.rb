# frozen_string_literal: true

# Imports named OpenStreetMap features in Hamburg into the Poi gazetteer.
#
# Fetching (network) and parsing (pure) are separate so the parser can be tested
# against a fixture, exactly as in StreetImporter and QuarterImporter.
#
# Two ways in, same parser:
#
#   * Overpass — one query at import time, never at request time. Default.
#   * A local file — for a fully offline import, or to re-run the parse without
#     hitting Overpass again:
#
#       osmium tags-filter hamburg-latest.osm.pbf -o pois.pbf \
#         nwr/leisure nwr/amenity nwr/landuse nwr/place nwr/tourism \
#         nwr/historic nwr/man_made nwr/railway
#       osmium export pois.pbf -f geojson -o pois.geojson
#       rake "pois:import[pois.geojson]"
#
#     Overpass JSON (an "elements" list) and GeoJSON (a "features" list) are
#     both accepted; the shape decides.
#
# OpenStreetMap data is ODbL — attribution is required wherever it is shown.
class PoiImporter
  # Rotated on failure, not load-balanced: the public instances throttle under
  # load and answer 504 for a query they served a minute earlier, and a retry
  # elsewhere is far more likely to succeed than the same host again.
  OVERPASS_URLS = [
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ].freeze
  # Hamburg plus a margin, as in QuarterImporter. Deliberately a rectangle and
  # not an Overpass area lookup: everything outside the city is dropped by the
  # Quarter polygons anyway, and a bbox cannot break when an area id changes.
  BBOX = [53.35, 8.40, 54.05, 10.40].freeze
  LAT_RANGE = (53.3..54.1)
  LNG_RANGE = (8.4..10.4)
  # Answers are cached here as they arrive, so a run that loses a query to a
  # throttled instance resumes instead of starting over.
  CACHE_DIR = Rails.root.join('tmp/pois')
  # Long enough to resume across a bad afternoon, short enough that a resumed
  # run is still one coherent snapshot.
  CACHE_TTL = 3.days

  TIMEOUT = 300
  # Between requests. The whole import is around 40 of them, so it takes tens of
  # minutes — it refreshes a register, and nothing waits on it.
  PAUSE = 5
  # Throttling is answered with a wait, not a faster retry.
  BACKOFF = 20
  RETRIES = 5

  # More than this many features with the same name in the same district means
  # the name does not identify a place — see Poi.generic_name?.
  GENERIC_THRESHOLD = 3

  # The OSM tags a feature is accepted for. This is the analogue of the Google
  # Places type allowlist (Location::VALID_TYPES) and the reason the Poi table
  # stays small: everything else in Hamburg's extract never enters.
  #
  # Filtering happens here rather than at match time on purpose — one place to
  # read, and an unwanted category is removed by re-importing.
  TAGS = {
    'leisure' => %w[park playground garden pitch sports_centre nature_reserve dog_park stadium marina],
    'amenity' => %w[school kindergarten hospital library theatre community_centre place_of_worship
                    university college fire_station social_facility marketplace townhall],
    'landuse' => %w[cemetery allotments recreation_ground village_green],
    'place' => %w[square neighbourhood city_block island],
    'tourism' => %w[museum zoo attraction artwork],
    'historic' => :any,
    'man_made' => %w[bridge lighthouse],
    # Stations, for the transit path only — see TRANSIT_CATEGORIES.
    # No tram_stop: Hamburg has had no tram since 1978, and the selector
    # returns nothing.
    'railway' => %w[station halt],
  }.freeze

  # Categories that must never be matched by a bare name. A station is called
  # "Barmbek", which is also a Stadtteil, and a great many are called after the
  # street they sit on. They are reachable only through TransitGazetteer, where
  # a "U/S" or "Haltestelle" prefix in the text is the whole signal.
  TRANSIT_CATEGORIES = %w[railway].freeze

  # Named, tagged, and not a place anyone means: Hamburg has thousands of
  # Stolpersteine, each historic=memorial carrying a person's name. Admitting
  # them would turn every name in a document into a candidate place.
  EXCLUDED = { 'memorial' => %w[stolperstein stolperschwelle] }.freeze

  def self.import!(...) = new(...).import!

  def initialize(path: nil, cache_dir: CACHE_DIR)
    @path = path
    @cache_dir = Pathname(cache_dir)
  end

  # Nothing is written to the table until every query has answered. A partial
  # import would be worse than none: import! empties the table first, so a
  # missing tag value would silently delete a whole category of places.
  def import!
    now = Time.current
    rows = parse(read)
    raise EmptyImportError, 'no features returned' if rows.empty?

    Poi.transaction do
      Poi.delete_all
      rows.each_slice(2000) do |slice|
        Poi.insert_all(slice.map { |row| row.merge(created_at: now, updated_at: now) }) # rubocop:disable Rails/SkipsModelValidations
      end
      mark_generic!
    end

    Rails.logger.info "PoiImporter: imported #{rows.size} POIs"
    rows.size
  end

  class EmptyImportError < StandardError; end

  # Raised when some queries never answered. Everything that did answer is
  # cached, so re-running resumes rather than starting over.
  class IncompleteImportError < StandardError
    attr_reader :failures

    def initialize(failures)
      @failures = failures
      super("#{failures.size} queries did not answer: #{failures.keys.join(', ')}. " \
            'Answers so far are cached; re-run pois:import to retry only these.')
    end
  end

  def read
    return File.read(@path) if @path.present?

    { 'elements' => fetch }
  end

  # One request per tag *value*, not one for everything and not even one per
  # tag group: the public Overpass instance answers a query covering every tag
  # with a 504, and so does a whole group as broad as leisure.
  #
  # Around 45 requests against instances that throttle, so a single failure
  # must not cost the other 44. Each answer is cached on disk as it arrives and
  # a failure is recorded rather than raised, so the run always gets as far as
  # it can and the next one picks up only what is missing.
  def fetch
    failures = {}
    elements = []
    requested = 0
    pending = queries

    pending.each_with_index do |(key, body), index|
      progress = "#{index + 1}/#{pending.size} #{key}"

      cached = cached_elements(key)
      if cached
        Rails.logger.info "PoiImporter: #{progress} — #{cached.size} cached"
        elements.concat(cached)
        next
      end

      sleep PAUSE if requested.positive?
      requested += 1

      begin
        fetched = store(key, request(body))
        Rails.logger.info "PoiImporter: #{progress} — #{fetched.size} fetched"
        elements.concat(fetched)
      rescue StandardError => e
        Rails.logger.warn "PoiImporter: #{progress} failed — #{e.class}: #{e.message.truncate(120)}"
        failures[key] = e
      end
    end

    raise IncompleteImportError, failures if failures.any?

    elements
  end

  # [cache key, query body] per tag value.
  def queries
    TAGS.flat_map do |tag, values|
      next [["#{tag}-any", query(tag, :any)]] if values == :any

      values.map { |value| ["#{tag}-#{value}", query(tag, [value])] }
    end
  end

  # What has already answered, so a resumed run can say so.
  def cached_keys
    queries.map(&:first).select { |key| cached_elements(key) }
  end

  def clear_cache!
    FileUtils.rm_rf(@cache_dir)
  end

  private

  # A cached answer older than CACHE_TTL is ignored, so a resumed import cannot
  # silently mix this week's data with last month's.
  def cached_elements(key)
    file = cache_file(key)
    return nil unless file.exist?
    return nil if file.mtime < CACHE_TTL.ago

    JSON.parse(file.read)
  rescue JSON::ParserError
    nil
  end

  def store(key, elements)
    file = cache_file(key)
    FileUtils.mkdir_p(file.dirname)
    file.write(JSON.generate(elements))
    elements
  end

  def cache_file(key)
    @cache_dir.join("#{key}.json")
  end

  public

  # Overpass rate-limits and times out under load; both are worth waiting out
  # rather than losing the whole import.
  def request(body, attempt: 1)
    url = OVERPASS_URLS[(attempt - 1) % OVERPASS_URLS.size]
    client = HTTPClient.new
    client.ssl_config.set_default_paths
    client.receive_timeout = TIMEOUT + 60

    JSON.parse(client.post_content(url, { data: body }))['elements'] || []
  rescue HTTPClient::BadResponseError, HTTPClient::TimeoutError, JSON::ParserError => e
    raise if attempt >= RETRIES

    Rails.logger.warn "PoiImporter: #{url} answered #{e.class} — retrying (#{attempt}/#{RETRIES})"
    sleep BACKOFF * attempt
    request(body, attempt: attempt + 1)
  end

  # `out center` collapses ways and relations to a single representative point,
  # which is all a map pin needs and saves carrying geometry we would only
  # reduce to a centroid ourselves.
  def query(tag, values)
    selector = values == :any ? "[#{tag}]" : %([#{tag}~"^(#{Array(values).join('|')})$"])
    # Applied here as well as in the parser: Stolpersteine alone are thousands
    # of features, and there is no reason to transfer them to drop them.
    rejections = EXCLUDED.map { |key, rejected| %([#{key}!~"^(#{rejected.join('|')})$"]) }.join

    <<~OVERPASS
      [out:json][timeout:#{TIMEOUT}];
      nwr#{selector}[name]#{rejections}(#{BBOX.join(',')});
      out center tags;
    OVERPASS
  end

  # Rows ready for Poi.insert_all. Pure with respect to the network, but it does
  # read the Quarter polygons: a POI is a point, and which Quarter and district
  # it falls into is exactly the question those polygons answer. A feature
  # outside every Quarter is not in Hamburg and is dropped, which is what keeps
  # the bbox margin harmless.
  def parse(payload)
    document = payload.is_a?(String) ? JSON.parse(payload) : payload
    elements = document['elements'] || document['features'] || []

    rows = elements.filter_map { |element| row_for(element) }
    deduplicate(rows)
  end

  private

  def row_for(element)
    tags = tags_for(element)
    name = tags['name'].to_s.squish
    category = accepted_category(tags)
    return nil if name.blank? || category.blank?

    identity = identity(element)
    point = point_for(element)
    quarters = point.present? ? Quarter.covering_quarters(*point) : []
    return nil if identity.blank? || point.blank? || quarters.empty?

    attributes(name: name, category: category, identity: identity, point: point, tags: tags, quarters: quarters)
  end

  def attributes(name:, category:, identity:, point:, tags:, quarters:)
    transit = TRANSIT_CATEGORIES.include?(category.split('=').first)
    osm_type, osm_id = identity
    latitude, longitude = point

    {
      name: name,
      normalized_name: Poi.normalize(name),
      category: category,
      osm_type: osm_type,
      osm_id: osm_id,
      latitude: latitude,
      longitude: longitude,
      quarter: quarters.first.name,
      quarters: quarters.map(&:name),
      district_number: quarters.first.district_number,
      postal_code: tags['addr:postcode'].to_s.squish.presence,
      aliases: Poi.aliases_for(name),
      # A station is exempt: "Barmbek" is a Stadtteil name and would be marked
      # generic at once, but on the transit path the prefix carries the meaning.
      generic: !transit && Poi.generic_name?(name),
      transit: transit,
    }
  end

  # The category the feature is accepted for, or nil when no tag admits it or an
  # exclusion rejects it.
  def accepted_category(tags)
    return nil if excluded?(tags)

    category_for(tags)
  end

  # The representative point, or nil when it is missing or implausible. The
  # range check is the same guard QuarterImporter uses: a service that changes
  # its mind about the projection must fail loudly, not import nonsense.
  def point_for(element)
    latitude, longitude = coordinates(element)
    return nil if latitude.blank? || longitude.blank?
    return nil unless LAT_RANGE.cover?(latitude) && LNG_RANGE.cover?(longitude)

    [latitude, longitude]
  end

  # Overpass carries type and id in their own fields; osmium's GeoJSON export
  # puts them in "@id" as "way/1234".
  def identity(element)
    return [element['type'], element['id']] if element['type'].in?(%w[node way relation])

    reference = element['id'] || element.dig('properties', '@id')
    type, id = reference.to_s.split('/')
    return nil unless type.in?(%w[node way relation])

    [type, id.to_i]
  end

  def tags_for(element)
    element['tags'] || element['properties'] || {}
  end

  def excluded?(tags)
    EXCLUDED.any? { |tag, values| values.include?(tags[tag].to_s.squish) }
  end

  def category_for(tags)
    TAGS.each do |tag, values|
      value = tags[tag].to_s.squish
      next if value.blank?
      next unless values == :any || values.include?(value)

      return "#{tag}=#{value}"
    end

    nil
  end

  # A node answers with lat/lon, a way or relation with a "center" (Overpass) or
  # a geometry (GeoJSON). For the latter the bounding-box centre stands in for a
  # true centroid: a pin on a park needs to be inside it, not at its mass centre.
  def coordinates(element)
    return [element['lat'], element['lon']] if element['lat'].present?

    center = element['center']
    return [center['lat'], center['lon']] if center.present?

    geometry_center(element['geometry'])
  end

  def geometry_center(geometry)
    return [nil, nil] if geometry.blank?

    return geometry['coordinates'].reverse if geometry['type'] == 'Point'

    points = Array(geometry['coordinates']).flatten.each_slice(2).to_a
    return [nil, nil] if points.empty?

    longitudes = points.map(&:first)
    latitudes = points.map(&:last)

    [(latitudes.min + latitudes.max) / 2.0, (longitudes.min + longitudes.max) / 2.0]
  end

  # The same feature can be tagged on both a way and its relation, and insert_all
  # would reject the duplicate osm_type/osm_id pair outright.
  def deduplicate(rows)
    rows.uniq { |row| [row[:osm_type], row[:osm_id]] }
  end

  # The count-based half of Poi.generic_name?: a name carried by more than
  # GENERIC_THRESHOLD features in the same district identifies a category, not a
  # place, and must never be pinned.
  def mark_generic!
    Poi.connection.execute(<<~SQL.squish)
      UPDATE pois SET generic = true
      FROM (
        SELECT normalized_name, district_number
        FROM pois
        WHERE transit = false
        GROUP BY normalized_name, district_number
        HAVING count(*) > #{GENERIC_THRESHOLD}
      ) common
      WHERE pois.transit = false
        AND pois.normalized_name = common.normalized_name
        AND pois.district_number IS NOT DISTINCT FROM common.district_number
    SQL
  end
end
