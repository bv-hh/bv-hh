# frozen_string_literal: true

require 'test_helper'

class DistrictsControllerTest < ActionDispatch::IntegrationTest
  test 'GET show without district' do
    get root_with_district_path(district: 'unknown')
    assert_redirected_to root_with_district_path(districts(:hamburg_nord))
  end

  test 'GET show with district' do
    get root_with_district_path(district: districts.first.name.parameterize)
    assert_response :success
    assert_select 'h1', text: 'Hamburg-Nord'
    assert_select 'input#hero-search.search-input', count: 1
  end

  test 'GET show leads with the next plenary session and lists the next public meetings apart from it' do
    district = districts(:hamburg_nord)
    assembly = meetings(:bv_oct)
    assembly.update!(date: 5.days.from_now.to_date)
    regional = meetings(:rega_ewi_oct)
    regional.update!(date: 2.days.from_now.to_date)

    get root_with_district_path(district:)

    assert_select '.card-header', text: /Nächste Bezirksversammlung.*in 5 Tagen/m
    assert_select ".card-header a[href='#{meeting_path(assembly, district:)}']", text: 'Tagesordnung ansehen'
    assert_select '.list-group-item', text: /Regionalausschuss Eppendorf-Winterhude/, count: 1
    assert_select ".list-group-item a[href='#{meeting_path(assembly, district:)}']", count: 0
  end

  test 'GET show links the Stadtteile of the district in the hero' do
    district = districts(:hamburg_nord)

    get root_with_district_path(district:)

    assert_select ".card a[href='#{quarter_path(district:, quarter: 'barmbek-nord')}']", text: 'Barmbek-Nord'
    assert_select "a[href='#{quarter_path(district:, quarter: 'lokstedt')}']", count: 0
  end

  test 'GET show leaves closed meetings out of the public meetings' do
    district = districts(:hamburg_nord)
    meetings(:rega_ewi_oct).update!(date: 2.days.from_now.to_date)
    committees(:rega_ewi).update!(public: false)

    get root_with_district_path(district:)

    assert_select '.list-group-item', text: /Regionalausschuss Eppendorf-Winterhude/, count: 0
  end

  test 'GET show offers an RSS feed for the whole district' do
    district = districts(:hamburg_nord)
    get root_with_district_path(district: district)

    assert_response :success
    assert_includes @response.body, feed_path(format: :rss, district: district.to_param)
    assert_includes @response.body, 'application/rss+xml'
  end

  test 'GET show lists the topics of the district with counts' do
    Document.update_all(topics: [])
    documents(:document_7).update_columns(topics: %w[radverkehr]) # rubocop:disable Rails/SkipsModelValidations
    district = districts(:hamburg_nord)

    get root_with_district_path(district: district)

    assert_select "a[href='#{topic_path(topic: 'radverkehr', district:)}']", text: /Radverkehr\s*1/
    assert_select "a[href='#{topic_path(topic: 'kultur', district:)}']", count: 0
  end
end
