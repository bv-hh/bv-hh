# frozen_string_literal: true

require 'test_helper'

class AdminControllerTest < ActionDispatch::IntegrationTest
  test 'GET show' do
    get admin_path(district: districts.first)
    assert_response :success
  end
end
