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

  test 'GET show and minutes sit under the committee of the meeting' do
    meeting = meetings(:rega_ewi_oct)
    committee_link = "nav[aria-label=Brotkrumen] a[href='#{committee_path(meeting.committee, district: meeting.district)}']"

    get meeting_path(meeting, district: meeting.district)
    assert_select committee_link, text: meeting.committee.name
    assert_select 'nav[aria-label=Brotkrumen] li[aria-current=page]', text: I18n.l(meeting.date)

    get minutes_meeting_path(meeting, district: meeting.district)
    assert_select committee_link
    assert_select 'nav[aria-label=Brotkrumen] a[href=?]', meeting_path(meeting, district: meeting.district)
    assert_select 'nav[aria-label=Brotkrumen] li[aria-current=page]', text: 'Protokoll'
  end

  test 'GET minutes' do
    meeting = meetings(:rega_ewi_oct)
    get minutes_meeting_path(meeting, district: districts.first)
    assert_response :success
    assert_includes @response.body, meeting.title
  end

  test 'GET allris redirects to the meeting' do
    meeting = meetings(:rega_ewi_oct)
    get allris_meetings_path(district: districts.first, allris_id: meeting.allris_id)
    assert_redirected_to meeting_path(meeting, district: meeting.district)
  end

  test 'GET allris without district redirects to root' do
    get allris_meetings_path(allris_id: 1)
    assert_redirected_to root_path
  end
end
