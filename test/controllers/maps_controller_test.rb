# frozen_string_literal: true

require 'test_helper'

class MapsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show' do
    get map_path
    assert_response :success

    get map_path(district: districts.first)
    assert_response :success
  end

  test 'GET markermarkers' do
    get markers_map_path
    assert_response :success

    get markers_map_path(district: districts.first)
    assert_response :success
  end
end
