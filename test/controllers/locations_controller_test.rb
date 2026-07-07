# frozen_string_literal: true

require 'test_helper'

class LocationsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show' do
    location = locations(:heilwigstrasse)
    get location_path(location, district: districts.first)
    assert_response :success
    assert_includes @response.body, location.name
  end

  test 'GET show redirects the bare id to the canonical path' do
    location = locations(:heilwigstrasse)
    get location_path(id: location.id, district: districts.first)
    assert_redirected_to location_path(location, district: location.district)
  end
end
