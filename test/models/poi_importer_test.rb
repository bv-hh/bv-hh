# frozen_string_literal: true

require 'test_helper'

class PoiImporterTest < ActiveSupport::TestCase
  setup do
    @rows = PoiImporter.new.parse(file_fixture('overpass_pois_sample.json').read)
    @by_name = @rows.index_by { |row| row[:name] }
    @cache_dir = Dir.mktmpdir('pois-cache')
  end

  teardown { FileUtils.rm_rf(@cache_dir) }

  test 'parse builds a row per named feature in an accepted category' do
    park = @by_name['Teststadtpark']

    assert_equal 'teststadtpark', park[:normalized_name]
    assert_equal 'leisure=park', park[:category]
    assert_equal 'node', park[:osm_type]
    assert_equal 1001, park[:osm_id]
    assert_in_delta 53.58, park[:latitude]
    assert_in_delta 10.0, park[:longitude]
    assert_equal '22305', park[:postal_code]
  end

  test 'parse derives Quarter and district from the polygons' do
    assert_equal 'Barmbek-Nord', @by_name['Teststadtpark'][:quarter]
    assert_equal ['Barmbek-Nord'], @by_name['Teststadtpark'][:quarters]
    assert_equal 4, @by_name['Teststadtpark'][:district_number]
    assert_equal 3, @by_name['Testfriedhof'][:district_number]
  end

  test 'parse collapses a way or relation to its representative point' do
    assert_in_delta 53.59, @by_name['Testschule'][:latitude]
    assert_in_delta 10.01, @by_name['Testschule'][:longitude]
  end

  test 'parse drops features outside the accepted tags' do
    assert_nil @by_name['Testbäckerei']
  end

  test 'parse drops features without a name' do
    assert_empty(@rows.select { |row| row[:osm_id] == 1003 })
  end

  test 'parse drops features outside every Quarter' do
    assert_nil @by_name['Testpark im Loch']
  end

  test 'parse drops Stolpersteine, which carry a person name' do
    assert_nil @by_name['Anna Testperson']
  end

  test 'parse drops natural features, which are not an accepted category' do
    assert_nil @by_name['Testteich']
  end

  test 'parse marks a Stadtteil name and a too-short name as generic' do
    assert @by_name['Barmbek-Nord'][:generic]
    assert @by_name['Hof'][:generic]
    assert_not @by_name['Teststadtpark'][:generic]
  end

  test 'parse marks stations as transit and exempts them from the generic rule' do
    station = @by_name['Barmbek']

    assert station[:transit]
    assert_not station[:generic], 'a station name matching a Stadtteil stays matchable via the transit prefix'
    assert_not @by_name['Teststadtpark'][:transit]
  end

  test 'parse records the spellings a document would use for a qualified name' do
    assert_equal ['testanlage'], @by_name['Hamburger Testanlage'][:aliases]
    assert_empty @by_name['Teststadtpark'][:aliases]
  end

  test 'parse deduplicates a feature repeated under the same osm id' do
    assert_equal(1, @rows.count { |row| row[:osm_type] == 'way' && row[:osm_id] == 2001 })
  end

  test 'parse reads the osmium GeoJSON export as well as Overpass JSON' do
    rows = PoiImporter.new.parse(file_fixture('osmium_pois_sample.geojson').read).index_by { |row| row[:name] }

    assert_equal 'way', rows['Testspielplatz'][:osm_type]
    assert_equal 555, rows['Testspielplatz'][:osm_id]
    assert_in_delta 53.58, rows['Testspielplatz'][:latitude]
    assert_in_delta 9.75, rows['Testspielplatz'][:longitude]
    assert_equal 'Lokstedt', rows['Testspielplatz'][:quarter]
    assert_equal 'amenity=library', rows['Testbücherhalle'][:category]
  end

  test 'one query per tag value, so no single request is too broad for Overpass' do
    queries = PoiImporter.new.queries
    expected = PoiImporter::TAGS.sum { |_tag, values| values == :any ? 1 : values.size }

    assert_equal expected, queries.size
    assert(queries.all? { |_key, query| query.include?('out center tags;') && query.include?('[name]') })
  end

  test 'every query is keyed by its tag and value, so answers cache separately' do
    keys = PoiImporter.new.queries.map(&:first)

    assert_includes keys, 'leisure-park'
    assert_includes keys, 'historic-any'
    assert_equal keys.uniq, keys
  end

  test 'a single value becomes its own selector, and :any matches the bare tag' do
    assert_includes PoiImporter.new.query('leisure', ['park']), '[leisure~"^(park)$"]'
    assert_includes PoiImporter.new.query('historic', :any), 'nwr[historic][name]'
  end

  test 'retries rotate through the endpoints rather than hammering one' do
    assert_operator PoiImporter::OVERPASS_URLS.size, :>, 1
    assert_operator PoiImporter::RETRIES, :>, PoiImporter::OVERPASS_URLS.size
  end

  test 'a cached answer is reused instead of re-requested' do
    importer = PoiImporter.new(cache_dir: @cache_dir)
    importer.send(:store, 'leisure-park', [{ 'type' => 'node', 'id' => 7,
                                             'lat' => 53.58, 'lon' => 10.0,
                                             'tags' => { 'leisure' => 'park', 'name' => 'Gecachter Park' } }])

    assert_includes importer.cached_keys, 'leisure-park'
    assert_equal 1, importer.send(:cached_elements, 'leisure-park').size
  end

  test 'a cached answer older than the TTL is ignored' do
    importer = PoiImporter.new(cache_dir: @cache_dir)
    importer.send(:store, 'leisure-park', [])
    file = importer.send(:cache_file, 'leisure-park')
    FileUtils.touch(file, mtime: (PoiImporter::CACHE_TTL + 1.day).ago.to_time)

    assert_empty importer.cached_keys
  end

  test 'clear_cache! discards the answers' do
    importer = PoiImporter.new(cache_dir: @cache_dir)
    importer.send(:store, 'leisure-park', [])

    importer.clear_cache!

    assert_empty importer.cached_keys
  end

  test 'the query rejects what the parser would drop anyway' do
    assert_includes PoiImporter.new.query('historic', :any), '[memorial!~"^(stolperstein|stolperschwelle)$"]'
  end
end
