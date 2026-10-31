# frozen_string_literal: true

require 'test_helper'

class KitchensinkControllerTest < ActionDispatch::IntegrationTest
  test 'GET show renders every chip' do
    get kitchensink_path
    assert_response :success
    assert_select 'h1', 'Chips and badges'
    assert_includes @response.body, locations(:heilwigstrasse).name
    assert_select 'a.rounded-pill', minimum: 1
  end
end
