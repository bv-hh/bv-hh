# frozen_string_literal: true

require 'test_helper'

class StatisticsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show' do
    get statistics_path(district: districts.first)
    assert_response :success
  end

  test 'shows topics, outcomes of Anträge and Stadtteile' do
    documents(:document_227).update!(topics: ['radverkehr'], quarters: ['Ohlsdorf'])

    get statistics_path(district: districts(:hamburg_nord))

    assert_select 'h2', 'Worüber beraten wird'
    assert_select 'h2', 'Was aus Anträgen wird'
    assert_select 'h2', 'Wo es um Orte geht'
    assert_select 'a[href=?]', topic_path(topic: Topic.find('radverkehr'), district: districts(:hamburg_nord).to_param)
    assert_select 'a[href=?]', quarter_path(district: districts(:hamburg_nord), quarter: 'ohlsdorf')
    assert_select '[data-controller=choropleth]'
    assert_select 'a[href=?]', 'https://www.statistik-nord.de/stadtteilprofile'
  end

  test 'shows all of Hamburg without a district, comparing the Bezirke and leaving out the Fraktionen' do
    documents(:document_227).update!(topics: ['radverkehr'])

    get statistics_path

    assert_response :success
    assert_select 'p', /\AHamburg ·/
    assert_select 'h2', 'Die Bezirke im Vergleich'
    assert_select 'a[href=?]', statistics_path(district: districts(:hamburg_nord))
    assert_select '#fraktionen', count: 0
    assert_select 'a[href=?]', topic_path(topic: Topic.find('radverkehr'), district: nil)
  end
end
