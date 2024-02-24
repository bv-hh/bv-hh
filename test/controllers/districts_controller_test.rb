# frozen_string_literal: true

require 'test_helper'

class DistrictsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show without district' do
    get root_with_district_path(district: 'unknown')
    assert_redirected_to root_with_district_path(districts(:hamburg_nord))
  end

  test 'GET show with district' do
    get root_with_district_path(district: districts.first.name.parameterize)
    assert_response :success
    assert_includes @response.body, 'Aktuell sehen Sie Drucksachen, Sitzungen und mehr aus <b>Hamburg-Nord</b>'
  end
end
