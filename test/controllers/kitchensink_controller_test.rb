# frozen_string_literal: true

require 'test_helper'

class KitchensinkControllerTest < ActionDispatch::IntegrationTest
  test 'GET show renders every chip' do
    get kitchensink_path
    assert_response :success
    assert_select 'h1', 'Chips, badges and lists'
    assert_includes @response.body, locations(:heilwigstrasse).name
    assert_select 'a.rounded-pill', minimum: 1
  end

  test 'GET show renders full and compact Drucksachen rows' do
    get kitchensink_path
    assert_select '.list-group-item.py-3 a.fw-semibold', minimum: 1
    assert_select '.list-group-item.py-2 a:not(.fw-semibold)', minimum: 1
  end
end
