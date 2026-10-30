# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test 'GET root' do
    get root_path
    assert_response :success
  end

  test 'GET root lists the topics of all districts with counts' do
    Document.update_all(topics: [])
    documents(:document_7).update_columns(topics: %w[radverkehr]) # rubocop:disable Rails/SkipsModelValidations

    get root_path

    assert_select "a[href='#{topic_path(topic: 'radverkehr', district: nil)}']", text: /Radverkehr\s*1/
    assert_select "a[href='#{topic_path(topic: 'kultur', district: nil)}']", count: 0
  end

  test 'GET root lists the next plenary session of each district, not its committees' do
    meetings(:bv_oct).update!(date: 3.days.from_now.to_date)
    meetings(:bv_oct).dup.tap { |later| later.update!(allris_id: nil, date: 10.days.from_now.to_date) }
    meetings(:rega_ewi_oct).update!(date: 1.day.from_now.to_date)

    get root_path

    assert_select '.list-group-item', count: 1
    assert_select '.list-group-item', text: /Hamburg-Nord\s*in 3 Tagen/
    assert_select ".list-group-item a.stretched-link[href='#{meeting_path(meetings(:bv_oct), district: districts(:hamburg_nord))}']"
  end

  test 'GET root links each district with its number of documents' do
    get root_path

    count = districts(:hamburg_nord).documents.complete.count
    assert_select "a[href='#{root_with_district_path(districts(:hamburg_nord))}']", text: 'Hamburg-Nord'
    assert_select '.card-text', text: /#{count}\s*Drucksachen/
  end

  test 'GET root has only its own search field, with the typeahead endpoints' do
    get root_path

    assert_select 'input.search-input', count: 1
    assert_select "input#hero-search.search-input[data-suggest-documents='#{suggest_documents_path(q: 'QUERY')}']"
  end

  test 'sub pages keep the search field in the navbar' do
    get about_path

    assert_select 'nav input.search-input', count: 1
  end

  test 'the district menu ends with a link to the overview' do
    get about_path

    assert_select '.dropdown-menu li:last-child a.dropdown-item[href=?]', root_path, text: 'Übersicht'
    assert_select '.dropdown-menu hr.dropdown-divider', count: 1
  end

  %i[imprint privacy about transparency mcp district_politics participation].each do |action|
    test "GET #{action}" do
      get send(:"#{action}_path")
      assert_response :success
    end
  end
end
