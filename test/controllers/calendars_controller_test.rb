# frozen_string_literal: true

require 'test_helper'

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show without district' do
    get calendar_path
    assert_response :success
  end

  test 'GET show with district' do
    get calendar_path(district: districts.first)
    assert_response :success
  end

  test 'GET show for a specific month' do
    meeting = meetings(:rega_ewi_oct)
    get calendar_path(district: districts.first, year: meeting.date.year, month: meeting.date.month)
    assert_response :success
    assert_includes @response.body, meeting.title
  end
end
