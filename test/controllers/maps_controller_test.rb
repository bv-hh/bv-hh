# frozen_string_literal: true

require 'test_helper'

class MapsControllerTest < ActionDispatch::IntegrationTest
  # The fixtures' meetings are in October 2023.
  setup { travel_to Date.new(2023, 10, 20) }

  test 'GET show' do
    get map_path
    assert_response :success
    assert_select '[data-controller=map][data-map-city-value=true]'
    assert_select 'input[name=zeitraum][value=aktuell][checked]'

    get map_path(district: districts(:hamburg_nord))
    assert_response :success
    assert_select '[data-controller=map][data-map-city-value=false]'
  end

  test 'GET show keeps the chosen range and topic' do
    get map_path(zeitraum: 'wahlperiode', thema: Topic.first.slug)

    assert_select 'input[name=zeitraum][value=wahlperiode][checked]'
    assert_select "select[name=thema] option[selected][value='#{Topic.first.slug}']"
  end

  test 'GET show leaves the box to the map when a district has none' do
    # The instance the controller gets: District.lookup memoizes them.
    district = District.lookup('hamburg-nord')
    box = district.attributes.slice('ne_lat', 'ne_lng', 'sw_lat', 'sw_lng')
    district.assign_attributes(ne_lat: nil, ne_lng: nil, sw_lat: nil, sw_lng: nil)

    get map_path(district:)

    assert_select '[data-controller=map][data-map-bounds-value="[]"]'
  ensure
    district.assign_attributes(box)
  end

  test 'GET show 404s for an unknown district' do
    get '/nirgendwo/map'

    assert_response :not_found
  end

  test 'GET areas outlines the district and its Stadtteile' do
    get areas_map_path(district: districts(:hamburg_nord))
    assert_response :success

    data = response.parsed_body
    assert_equal ['Hamburg-Nord'], data['districts'].pluck('name')
    assert_includes data['quarters'].pluck('name'), 'Barmbek-Nord'
    assert(data['quarters'].all? { |quarter| quarter['polygons'].is_a?(Array) })
  end

  test 'GET markers pins the places of the range and counts them per area' do
    get markers_map_path(district: districts(:hamburg_nord))
    assert_response :success

    data = response.parsed_body
    ids = data['places'].map(&:first)
    assert_includes ids, locations(:heilwigstrasse).id
    assert_includes ids, locations(:stadtpark).id
    assert_equal 2, data['areas']['quarters']['Barmbek-Nord']
    assert_operator data['counts']['placed'], :>=, 2
  end

  test 'GET markers is empty for a range without Drucksachen' do
    get markers_map_path(zeitraum: 'letzte-wahlperiode')

    assert_empty response.parsed_body['places']
  end

  test 'GET documents lists the Drucksachen with a place in the box' do
    get documents_map_path(bbox: '53.58,9.99,53.60,10.02')
    assert_response :success

    assert_select 'turbo-frame#map-documents'
    assert_select 'turbo-frame#map-documents p', text: /#{MapQuery::RANGE_HINTS['aktuell']}/
    assert_select 'a', text: /Heilwigstraße/
  end

  test 'GET documents leaves out places outside the box' do
    get documents_map_path(bbox: '53.0,9.0,53.1,9.1')

    assert_select 'turbo-frame#map-documents .list-group-item', count: 0
  end

  test 'GET documents without a box lists nothing' do
    get documents_map_path(bbox: 'a,b,c,d')

    assert_response :success
    assert_select '.list-group-item', count: 0
  end

  test 'GET place renders the popup with the Drucksachen of the range' do
    location = locations(:heilwigstrasse)
    get place_map_path(location_id: location.id)
    assert_response :success

    assert_select 'strong', text: location.name
    assert_select 'ul.map-popup-documents li', count: 1
    assert_select 'a[href=?]', location_path(location, district: location.district)
  end

  test 'GET place escapes names from the registers' do
    location = locations(:stadtpark)
    location.update!(name: '<img src=x onerror=alert(1)>')

    get place_map_path(location_id: location.id)

    assert_includes response.body, '&lt;img src=x onerror=alert(1)&gt;'
    assert_not_includes response.body, '<img src=x'
  end
end
