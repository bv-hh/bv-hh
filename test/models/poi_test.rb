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

  test 'for matches a spelling the document uses instead of the OSM name' do
    assert_equal [pois(:hamburger_testpark)], Poi.for('Testpark', districts(:hamburg_nord)).to_a
  end

  test 'aliases_for strips the city qualifier OSM puts in the name' do
    assert_equal ['testpark'], Poi.aliases_for('Hamburger Testpark')
    assert_equal ['testpark'], Poi.aliases_for('Testpark Hamburg')
    assert_empty Poi.aliases_for('Teststadtpark')
  end

  test 'aliases_for records the spelling without the apostrophe' do
    assert_equal ['ohlendorffscher park'], Poi.aliases_for("Ohlendorff'scher Park")
    assert_equal ['ohlendorffscher park'], Poi.aliases_for("Ohlendorff\u2019scher Park")
  end

  test 'aliases_for combines the apostrophe and the city qualifier' do
    # "hamburger kapt n huk" is the normalized name itself, so it is not an alias.
    assert_equal(['hamburger kaptn huk', 'kapt n huk', 'kaptn huk'],
                 Poi.aliases_for("Hamburger Käpt'n Huk").map { |alias_name| alias_name.tr('äöü', 'aou') })
  end

  test 'aliases_for drops a remainder too short to identify anything' do
    assert_empty Poi.aliases_for('Hamburger Hof')
  end

  test 'rebuild_aliases! recomputes in place without a re-import' do
    pois(:hamburger_testpark).update_columns(aliases: []) # rubocop:disable Rails/SkipsModelValidations

    assert_equal 1, Poi.rebuild_aliases!
    assert_equal ['testpark'], pois(:hamburger_testpark).reload.aliases
  end

  test 'transit_for matches the station name without its city qualifier' do
    assert_equal [pois(:hamburg_dammtor_station)], Poi.transit_for('Dammtor', districts(:hamburg_nord)).to_a
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

  # --- stations just over the district border ----------------------------------

  test 'transit_near_for finds a station close to the border of another district' do
    station = border_station('Grenzbahnhof', latitude: 53.625)

    assert_equal [station], Poi.transit_near_for('Grenzbahnhof', districts(:hamburg_nord)).to_a
  end

  test 'transit_near_for refuses one further away than the threshold' do
    border_station('Fernbahnhof', latitude: 53.65)

    assert_empty Poi.transit_near_for('Fernbahnhof', districts(:hamburg_nord))
  end

  test 'near_for never answers with a station, however close it is' do
    border_station('Grenzbahnhof', latitude: 53.625)

    assert_empty Poi.near_for('Grenzbahnhof', districts(:hamburg_nord)),
                 'a station stays reachable only through the transit path'
  end

  def border_station(name, latitude:)
    Poi.create!(name: name, normalized_name: Poi.normalize(name), latitude: latitude, longitude: 10.02,
                district_number: 5, transit: true, category: 'railway=station',
                osm_type: 'node', osm_id: name.hash.abs)
  end
end
