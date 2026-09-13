# frozen_string_literal: true

require 'test_helper'

class LocationCleanupTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    Quarter.reset!
    StreetGazetteer.reset!
  end

  teardown do
    Quarter.reset!
    StreetGazetteer.reset!
  end

  test 'keeps a location the street register still answers with' do
    location = Location.determine_locations('Testallee', @district).sole

    assert_not_includes stale_locations, location
  end

  test 'keeps a location the POI gazetteer still answers with' do
    location = Location.determine_locations('Teststadtpark', @district).sole

    assert_not_includes stale_locations, location
  end

  test 'keeps a station location, which only the transit path produces' do
    location = Location.determine_station_locations('Barmbek', @district).sole

    assert_not_includes stale_locations, location
  end

  test 'finds a Stadtteil geocoded to a point before that stopped being allowed' do
    location = build_legacy(extracted_name: 'Barmbek-Nord', name: 'Barmbek-Nord')

    assert_includes stale_locations, location
    assert_equal 'Stadtteil, recorded on the document instead', reason_for(location)
  end

  test 'finds a place no register answers with' do
    location = build_legacy(extracted_name: 'Stadtpark', name: 'Ententeich im Stadtpark')

    assert_includes stale_locations, location
    assert_equal 'no register answers with this place', reason_for(location)
  end

  test 'finds a blocked name' do
    location = build_legacy(extracted_name: 'Deutschland', name: 'Deutschland')

    assert_includes stale_locations, location
    assert_equal 'blocked name', reason_for(location)
  end

  test 'apply! deletes the stale rows and the document links with them' do
    location = build_legacy(extracted_name: 'Stadtpark', name: 'Ententeich im Stadtpark')
    document = Document.create!(district: @district, title: 'Test', allris_id: 424_242)
    document.document_locations.create!(location: location)

    link = document.document_locations.sole
    LocationCleanup.new.apply!

    assert_not Location.exists?(location.id)
    assert_not DocumentLocation.exists?(link.id)
  end

  private

  def stale_locations
    LocationCleanup.new.stale.map(&:location)
  end

  def reason_for(location)
    LocationCleanup.new.stale.find { |entry| entry.location == location }&.reason
  end

  def build_legacy(extracted_name:, name:)
    Location.create!(district: @district, extracted_name: extracted_name, name: name,
                     latitude: 53.58, longitude: 10.0, place_id: 'ChIJtestlegacyplaceid')
  end
end
