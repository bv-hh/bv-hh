# frozen_string_literal: true

require 'test_helper'

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show' do
    get statistics_path(district: districts.first)
    assert_response :success
  end
end
