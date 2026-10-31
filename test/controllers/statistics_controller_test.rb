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
  end
end
