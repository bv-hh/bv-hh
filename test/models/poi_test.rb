# frozen_string_literal: true

require 'test_helper'

class PoiTest < ActiveSupport::TestCase
  test 'for returns POIs of the district only' do
    assert_equal [pois(:teststadtpark)], Poi.for('Teststadtpark', districts(:hamburg_nord)).to_a
  end

  test 'for normalizes the name the same way the street gazetteer does' do
    assert_equal [pois(:teststadtpark)], Poi.for('  TESTSTADTPARK ', districts(:hamburg_nord)).to_a
  end

  test 'for skips names too common to identify a place' do
    assert_empty Poi.for('Spielplatz', districts(:hamburg_nord))
  end

  test 'for never answers with a station, whose bare name means something else' do
    assert_empty Poi.for('Barmbek', districts(:hamburg_nord))
  end

  test 'transit_for answers with the station' do
    assert_equal [pois(:barmbek_station)], Poi.transit_for('Barmbek', districts(:hamburg_nord)).to_a
  end

  test 'generic_name? rejects Stadtteil names and short names' do
    assert Poi.generic_name?('Barmbek-Nord')
    assert Poi.generic_name?('Hof')
    assert_not Poi.generic_name?('Teststadtpark')
    assert Poi.generic_name?('Teststadtpark', occurrences: PoiImporter::GENERIC_THRESHOLD + 1)
  end

  test 'formatted_address reads like a street register address' do
    assert_equal 'Teststadtpark, 22305 Barmbek-Nord', pois(:teststadtpark).formatted_address
  end

  test 'place_key identifies the OSM feature' do
    assert_equal 'osm:way/1001', pois(:teststadtpark).place_key
  end
end
