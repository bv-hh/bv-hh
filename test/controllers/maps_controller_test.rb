# frozen_string_literal: true

require 'test_helper'

class MapsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show' do
    get map_path
    assert_response :success

    get map_path(district: districts.first)
    assert_response :success
  end

  test 'GET show as JSON carries the district outline' do
    get map_path(district: districts(:hamburg_nord), format: :json)
    assert_response :success

    data = response.parsed_body

    assert data['boundary'].present?, 'the district is outlined by its Stadtteile'
    assert_equal [Array, Array, Array], [data['boundary'], data['boundary'].first,
                                         data['boundary'].first.first].map(&:class)
    assert data['bounds'].present?
  end

  test 'GET show as JSON has no boundary for the city-wide map' do
    get map_path(format: :json)
    assert_response :success

    assert_nil response.parsed_body['boundary']
  end

  test 'GET markermarkers' do
    get markers_map_path
    assert_response :success

    get markers_map_path(district: districts.first)
    assert_response :success
  end
end
