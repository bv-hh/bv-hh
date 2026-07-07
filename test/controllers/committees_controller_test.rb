# frozen_string_literal: true

require 'test_helper'

class CommitteesControllerTest < ActionDispatch::IntegrationTest
  test 'GET index' do
    get committees_path(district: districts.first)
    assert_response :success
    assert_includes @response.body, committees(:rega_ewi).name
  end

  test 'GET index shows the average minutes volume' do
    committees(:rega_ewi).update!(average_word_count: 1234)

    get committees_path(district: districts.first)

    assert_response :success
    assert_includes @response.body, 'Durchschnittlicher Umfang'
    assert_includes @response.body, '1.234 Wörter'
  end

  test 'GET show' do
    committee = committees(:rega_ewi)
    get committee_path(committee, district: districts.first)
    assert_response :success
    assert_includes @response.body, committee.name
  end

  test 'GET show renders one combined chart with documents and minutes on a second axis' do
    committee = committees(:rega_ewi)

    get committee_path(committee, district: districts.first)

    assert_response :success
    assert_includes @response.body, 'Anzahl Drucksachen'
    assert_includes @response.body, 'Umfang der Niederschriften (Wörter)'
    assert_includes @response.body, '"yAxisID":"words"' # word-count series on the secondary axis
  end

  test 'GET show summarises recent average words and duration below the chart' do
    committee = committees(:rega_ewi)
    meetings(:rega_ewi_oct).agenda_items.create!(minutes: 'a b c d e') # 5 words; meeting runs 18:00-19:15 => 1,25 h

    get committee_path(committee, district: districts.first)

    assert_response :success
    assert_includes @response.body, 'Sitzungen mit Niederschrift:'
    assert_includes @response.body, '5 Wörter'
    assert_includes @response.body, '1,25 h'
  end

  test 'GET show lists per-meeting duration and minutes volume' do
    committee = committees(:rega_ewi)
    meetings(:rega_ewi_oct).agenda_items.create!(minutes: 'a b c d e') # 5 words, meeting runs 18:00-19:15

    get committee_path(committee, district: districts.first)

    assert_response :success
    assert_includes @response.body, 'Dauer'
    assert_includes @response.body, 'Umfang'
    assert_includes @response.body, ' h' # duration rendered in hours
    assert_includes @response.body, '5 Wörter'
  end
end
