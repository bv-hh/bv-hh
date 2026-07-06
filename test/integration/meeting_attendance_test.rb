# frozen_string_literal: true

require 'test_helper'

class MeetingAttendanceTest < ActionDispatch::IntegrationTest
  setup do
    @district = districts(:hamburg_nord)
    @meeting = @district.meetings.create!(allris_id: 5000, title: 'Sitzung des Ausschusses', date: Date.new(2026, 1, 15))
    party = @district.parties.create!(allris_id: 1, name: 'SPD-Fraktion')
    member = @district.members.create!(allris_id: 10, name: 'Hans Müller', party:)
    @meeting.attendances.create!(member:, name: 'Herr Müller', party_hint: 'SPD', role: 'Ausschussmitglied')
    @meeting.attendances.create!(name: 'Frau Fremd', party_hint: 'CDU', role: 'Stellvertr. Ausschussmitglied', substitute: true)
  end

  test 'attendance page renders and is noindex' do
    get attendance_meeting_path(@meeting, district: @district)

    assert_response :success
    assert_select 'meta[name="robots"][content="noindex"]'
    assert_select 'table tbody tr td', text: 'Herr Müller'
    assert_select 'table tbody tr td', text: 'Hans Müller' # matched member shown
    assert_select 'span.badge', text: 'Vertretung'
  end
end
