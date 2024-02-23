# frozen_string_literal: true

require 'test_helper'

class MeetingsControllerTest < ActionDispatch::IntegrationTest

  test 'GET index' do
    get meetings_path(district: districts.first)
    assert_response :success
    assert_includes @response.body, meetings.first.title
  end

  test 'GET show' do
    meeting = meetings(:rega_ewi_oct)
    get meeting_path(meeting, district: districts.first)
    assert_response :success
    assert_includes @response.body, meeting.title
  end
end
