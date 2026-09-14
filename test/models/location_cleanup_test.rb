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

  test 'names the district that owns the street when a row is merely misfiled' do
    location = foreign_location
    location.update!(district: @district)

    assert_includes stale_locations, location
    assert_equal 'not in Hamburg-Nord, the register places it in Wandsbek', reason_for(location)
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

  # --- links left behind by the cross-district reuse -------------------------

  test 'finds a document claiming a location its own district would not resolve' do
    location = foreign_location
    link_to(location, district: @district)

    entry = links_for(location).sole

    assert_equal @district, entry.district
    assert_equal 1, entry.documents
  end

  test 'keeps a link from the district the register places the street in' do
    location = Location.determine_locations('Testallee', @district).sole
    link_to(location, district: @district)

    assert_empty links_for(location)
  end

  test 'apply! drops the foreign links without deleting the location' do
    location = foreign_location
    link = link_to(location, district: @district)

    LocationCleanup.new.apply!

    assert Location.exists?(location.id), 'Weitweg is a real street in Wandsbek'
    assert_not DocumentLocation.exists?(link.id)
  end

  test 'apply! reports the locations and the links separately' do
    build_legacy(extracted_name: 'Stadtpark', name: 'Ententeich im Stadtpark')
    link_to(foreign_location, district: @district)

    result = LocationCleanup.new.apply!

    assert_operator result.locations, :positive?
    assert_equal 1, result.links
  end

  test 'apply! reports the documents that lost a link, for reassignment' do
    stale_document = link_to(build_legacy(extracted_name: 'Stadtpark', name: 'Ententeich im Stadtpark'),
                             district: @district).document
    foreign_document = link_to(foreign_location, district: @district).document

    result = LocationCleanup.new.apply!

    assert_includes result.document_ids, stale_document.id
    assert_includes result.document_ids, foreign_document.id, 'the row stays, but this document may not claim it'
  end

  test 'apply! leaves out a document whose link it keeps' do
    kept = link_to(Location.determine_locations('Testallee', @district).sole, district: @district).document

    assert_not_includes LocationCleanup.new.apply!.document_ids, kept.id
  end

  private

  # A row the register places in Wandsbek, which Hamburg-Nord documents used to
  # be able to claim because the reuse was not district-confined.
  def foreign_location
    wandsbek = District.create!(name: 'Wandsbek', order: 5, allris_base_url: 'https://example.test')

    Location.determine_locations('Weitweg', wandsbek).sole
  end

  def link_to(location, district:)
    document = Document.create!(district: district, title: 'Test', allris_id: rand(1_000_000))

    document.document_locations.create!(location: location)
  end

  def links_for(location)
    LocationCleanup.new.stale_links.select { |entry| entry.location == location }
  end

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
