# frozen_string_literal: true

require 'test_helper'

class AgendaItemsControllerTest < ActionDispatch::IntegrationTest
  test 'GET allris redirects to the meeting minutes' do
    agenda_item = agenda_items(:agenda_item_10)
    get allris_agenda_items_path(district: districts.first, allris_id: agenda_item.allris_id)
    assert_redirected_to minutes_meeting_path(agenda_item.meeting, district: agenda_item.district, anchor: agenda_item.id)
  end

  test 'GET allris without district redirects to root' do
    get allris_agenda_items_path(allris_id: 1)
    assert_redirected_to root_path
  end

  test 'GET suggest returns json' do
    get suggest_agenda_items_path(district: districts.first, q: 'Tagesordnung')
    assert_response :success
    assert_equal 'application/json', @response.media_type
    assert_kind_of Array, JSON.parse(@response.body)
  end
end
