# == Schema Information
#
# Table name: locations
#
#  id                :integer          not null, primary key
#  name              :string
#  place_id          :string
#  latitude          :float
#  longitude         :float
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  normalized_name   :string
#  extracted_name    :string
#  district_id       :integer
#  formatted_address :string
#
# Indexes
#
#  index_locations_on_district_id      (district_id)
#  index_locations_on_name             (name)
#  index_locations_on_normalized_name  (normalized_name)
#  index_locations_on_place_id         (place_id)
#

# frozen_string_literal: true

require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    # Quarter memoizes its polygons per process, so any test that changes the
    # table has to be isolated from the rest.
    Quarter.reset!
  end

  teardown { Quarter.reset! }

  test 'determine_locations resolves a gazetteer street from register coordinates without Google' do
    location = nil
    assert_difference -> { Location.count }, 1 do
      location = Location.determine_locations('Testallee', @district).sole
    end

    assert_equal 'Testallee', location.name
    assert_in_delta 53.58, location.latitude
    assert_in_delta 10.03, location.longitude
    assert_equal 'gazetteer:02;4;01;401;0401;T0010', location.place_id
    assert_equal 'Testallee, 22305 Barmbek-Nord', location.formatted_address
    assert_equal @district, location.district
  end

  test 'determine_locations resolves a cross-district street whose point is outside the district bbox' do
    location = Location.determine_locations('Julius-Vosseler-Straße', @district).sole

    assert_equal 'Julius-Vosseler-Straße', location.name
    assert_equal @district, location.district
  end

  test 'determine_locations reuses an existing location on the second call' do
    Location.determine_locations('Testallee', @district)

    assert_no_difference -> { Location.count } do
      Location.determine_locations('Testallee', @district)
    end
  end

  test 'determine_locations returns nothing for a blocked name' do
    assert_empty Location.determine_locations('Hamburg', @district)
  end

  test 'determine_locations fills the denormalised place columns from the register' do
    location = Location.determine_locations('Testallee', @district).sole

    assert_equal ['Barmbek-Nord'], location.quarters
    assert_equal 'testallee', location.street_name
  end

  # --- a street belongs to the district the register puts it in ---------------

  test 'does not lend a street to a district the register places it outside' do
    wandsbek = District.create!(name: 'Wandsbek', order: 5, allris_base_url: 'https://example.test')

    assert_predicate Location.determine_locations('Weitweg', wandsbek), :one?, 'precondition'
    assert_empty Location.determine_locations('Weitweg', @district)
  end

  test 'resolves a street just over the border, which the district does not own' do
    Street.create!(name: 'Grenzweg', latitude: 53.625, longitude: 10.02, district_numbers: [5],
                   street_key: '02;5;00;000;0000;G0010')

    location = Location.determine_locations('Grenzweg', @district).sole

    assert_equal 'Grenzweg', location.name
    assert_equal @district, location.district, 'the row belongs to the district that wrote the name'
  end

  test 'prefers the district own street over one across the border' do
    Street.create!(name: 'Testallee', latitude: 53.625, longitude: 10.02, district_numbers: [5],
                   street_key: '02;5;00;000;0000;T0020')

    location = Location.determine_locations('Testallee', @district).sole

    assert_equal streets(:testallee).latitude, location.latitude
  end

  test 'pins a station just over the border, reached only through the transit path' do
    Poi.create!(name: 'Grenzbahnhof', normalized_name: 'grenzbahnhof', latitude: 53.625, longitude: 10.02,
                district_number: 5, transit: true, category: 'railway=station', osm_type: 'node', osm_id: 9901)

    assert_equal 'Grenzbahnhof', Location.determine_station_locations('Grenzbahnhof', @district).sole.name
    assert_empty Location.determine_locations('Grenzbahnhof', @district), 'the plain name still reaches no station'
  end

  test 'never reuses a station row for the plain name that made it' do
    Poi.create!(name: 'Grenzbahnhof', normalized_name: 'grenzbahnhof', latitude: 53.625, longitude: 10.02,
                district_number: 4, transit: true, category: 'railway=station', osm_type: 'node', osm_id: 9902)
    Location.determine_station_locations('Grenzbahnhof', @district).sole

    assert_empty Location.determine_locations('Grenzbahnhof', @district),
                 'the row exists, but only the transit path may have it'
  end

  test 'reuses an existing row within the district that owns the street' do
    first = Location.determine_locations('Testallee', @district).sole

    assert_equal [first], Location.determine_locations('Testallee', @district).to_a
  end

  test 'place_attributes does not borrow a same-named street from another district' do
    %w[4 5].zip([['Barmbek-Nord'], ['Duvenstedt']]).each do |number, quarters|
      Street.create!(name: 'Doppelweg', latitude: 53.58, longitude: 10.03, quarters: quarters,
                     district_numbers: [number.to_i], street_key: "02;#{number};00;000;0000;D00#{number}")
    end

    attributes = Location.place_attributes('Doppelweg', 53.58, 10.03, @district)

    assert_equal ['Barmbek-Nord'], attributes[:quarters]
  end

  test 'place_attributes takes the union of Quarters across every Bezirk' do
    # streets(:julius_vosseler) is one register row carrying Bezirk 3 and 4, so
    # narrowing to the district still yields the whole street.
    attributes = Location.place_attributes('Julius-Vosseler-Straße', 53.58, 9.75, @district)

    assert_equal ['Lokstedt', 'Groß Borstel'], attributes[:quarters]
    assert_equal 'julius vosseler straße', attributes[:street_name]
  end

  test 'place_attributes falls back to point-in-polygon when no street matches' do
    attributes = Location.place_attributes('Stadtpark', 53.5975, 10.0150, @district)

    assert_nil attributes[:street_name]
    assert_equal ['Barmbek-Nord'], attributes[:quarters]
  end

  test 'place_attributes prefers the register over the representative point' do
    # The point alone sits in Lokstedt, but the register says the street also
    # runs through Groß Borstel — the whole street has to win.
    attributes = Location.place_attributes('Julius-Vosseler-Straße', 53.58, 9.75, @district)

    assert_includes attributes[:quarters], 'Groß Borstel'
    assert_not_equal Quarter.covering(53.58, 9.75), attributes[:quarters]
  end

  test 'place_attributes returns empty Quarters for a point outside Hamburg' do
    attributes = Location.place_attributes('Deutschland', 51.1657, 10.4515, @district)

    assert_empty attributes[:quarters]
  end

  # --- Hamburg bounds -------------------------------------------------------

  # streets.yml has no Quarter around it, and it is the shape of the real bug:
  # Norderstedt sits inside Hamburg-Nord's bounding rectangle.
  OUTSIDE_HAMBURG = [53.6742, 9.9894].freeze

  test 'outside_district? rejects a point the district bounding box would accept' do
    assert_not Location.out_of_bounds?(*OUTSIDE_HAMBURG, @district.bounds),
               'precondition: the rectangle accepts this point'
    assert Location.outside_district?(*OUTSIDE_HAMBURG, @district)
  end

  test 'outside_district? accepts a point inside the district' do
    assert_not Location.outside_district?(53.5891, 10.0028, @district)
  end

  # The old rectangle accepted anything in its box, including places belonging
  # to a neighbouring Bezirk. The real outline does not.
  test 'outside_district? rejects a point in another Bezirk' do
    lokstedt = quarters(:lokstedt)
    point = [lokstedt.min_lat + 0.01, lokstedt.min_lng + 0.01]

    assert_equal ['Lokstedt'], Quarter.covering(*point), 'precondition: the point is in Bezirk 3'
    assert Location.outside_district?(*point, @district), 'but hamburg_nord is Bezirk 4'
  end

  test 'district contains? follows its Stadtteile, not its bounding box' do
    assert @district.contains?(53.5891, 10.0028)
    assert_not @district.contains?(*OUTSIDE_HAMBURG)
  end

  test 'outside_district? falls back to the bounding box when no boundaries are imported' do
    Quarter.delete_all
    Quarter.reset!

    assert_not Location.outside_district?(*OUTSIDE_HAMBURG, @district),
               'without polygons it can only fall back to the rectangle'
  end

  # --- coordinate repair ----------------------------------------------------

  test 'repair_coordinates! snaps an out-of-Hamburg point onto its register street' do
    location = locations(:heilwigstrasse)
    location.update!(latitude: OUTSIDE_HAMBURG.first, longitude: OUTSIDE_HAMBURG.last)

    assert_equal location, location.repair_coordinates!
    assert_in_delta streets(:heilwigstrasse).latitude, location.latitude
    assert_in_delta streets(:heilwigstrasse).longitude, location.longitude
    assert_equal "gazetteer:#{streets(:heilwigstrasse).street_key}", location.place_id
  end

  test 'repair_coordinates! leaves a location that is already inside Hamburg alone' do
    location = locations(:heilwigstrasse)

    assert_nil location.repair_coordinates!
  end

  test 'repair_coordinates! refuses to snap across districts' do
    # weitweg is registered in Bezirk 5 only, so a Hamburg-Nord location of that
    # name must not be dragged onto it.
    location = Location.create!(district: @district, name: 'Weitweg', extracted_name: 'weitweg',
                                latitude: OUTSIDE_HAMBURG.first, longitude: OUTSIDE_HAMBURG.last)

    assert_nil location.repair_coordinates!
  end

  test 'place_attributes gives no Quarters to a point outside Hamburg' do
    # Even though the register knows a Heilwigstraße, this point is not in it.
    attributes = Location.place_attributes('Heilwigstraße', *OUTSIDE_HAMBURG, @district)

    assert_empty attributes[:quarters]
    assert_equal 'heilwigstraße', attributes[:street_name], 'the street name still applies'
  end

  # --- Stadtteile are areas, not points ---------------------------------------

  test 'determine_locations refuses to geocode a Stadtteil name' do
    assert_no_difference -> { Location.count } do
      assert_empty Location.determine_locations('Barmbek-Nord', @district)
    end
  end

  test 'determine_locations is case insensitive about Stadtteil names' do
    assert_empty Location.determine_locations('barmbek-nord', @district)
  end

  test 'determine_locations still resolves a street' do
    assert_equal ['Testallee'], Location.determine_locations('Testallee', @district).map(&:name)
  end

  test 'determine_locations resolves a POI the street register does not know' do
    location = Location.determine_locations('Teststadtpark', @district).sole

    assert_equal 'Teststadtpark', location.name
    assert_equal 'osm:way/1001', location.place_id
    assert_equal 'Teststadtpark, 22305 Barmbek-Nord', location.formatted_address
    assert_in_delta 53.58, location.latitude
  end

  test 'determine_locations prefers the street register over the POI gazetteer' do
    Poi.create!(name: 'Testallee', category: 'leisure=park', osm_type: 'node', osm_id: 9001,
                latitude: 53.58, longitude: 10.03, district_number: 4, quarters: ['Barmbek-Nord'])

    assert_equal 'gazetteer:02;4;01;401;0401;T0010',
                 Location.determine_locations('Testallee', @district).sole.place_id
  end

  test 'determine_locations falls back to a trigram match for OCR damage' do
    location = Location.determine_locations('Testalee', @district).sole

    assert_equal 'Testallee', location.name
    assert_equal 'Testalee', location.extracted_name
  end

  test 'determine_locations answers nothing for a name no register knows' do
    assert_empty Location.determine_locations('Sommermonaten', @district)
  end

  test 'determine_locations never answers with a generic POI name' do
    assert_empty Location.determine_locations('Spielplatz', @district)
  end

  test 'determine_locations never answers with a station on the plain path' do
    assert_empty Location.determine_locations('Barmbek', @district)
  end
end
