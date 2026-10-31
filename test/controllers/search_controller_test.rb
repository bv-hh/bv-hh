# frozen_string_literal: true

require 'test_helper'

class SearchControllerTest < ActionDispatch::IntegrationTest
  test 'GET show with a term' do
    get search_path(district: districts.first, q: 'Eingabe')
    assert_response :success
  end

  test 'GET show without a district searches all districts' do
    get search_path(q: 'Eingabe')
    assert_response :success
  end

  test 'GET show with an empty term' do
    get search_path(district: districts.first)
    assert_response :success
  end

  test 'GET show redirects when the term matches a document number' do
    document = documents(:document_7)
    get search_path(district: districts.first, q: document.number)
    assert_redirected_to document_path(document, district: districts.first)
  end

  test 'GET show with a topic keeps only documents tagged with it' do
    Document.update_all(topics: [])
    get search_path(district: districts.first, q: 'Eingabe', topic: 'radverkehr')

    assert_response :success
    assert_not_includes @response.body, documents(:document_7).number

    documents(:document_7).update_columns(topics: %w[radverkehr]) # rubocop:disable Rails/SkipsModelValidations
    get search_path(district: districts.first, q: 'Eingabe', topic: 'radverkehr')

    assert_includes @response.body, documents(:document_7).number
  end

  test 'GET show links each Bezirk with its results and marks the current one' do
    get search_path(district: districts(:hamburg_nord), q: 'Eingabe')

    assert_select 'nav[aria-label=Bezirke] a[aria-current=page]', text: /Hamburg-Nord/
    assert_select 'nav[aria-label=Bezirke] a[href=?]', search_path(district: nil, q: 'Eingabe'), text: /Alle Bezirke/
  end

  test 'GET show sends the old all_districts checkbox to the search without a district' do
    get search_path(district: districts(:hamburg_nord), q: 'Eingabe', all_districts: 'true', order: 'relevance')

    assert_redirected_to search_path(district: nil, q: 'Eingabe', order: 'relevance')
  end

  test 'GET show passes only search parameters on to the search in all Bezirke' do
    get "#{search_path(district: districts(:hamburg_nord), q: 'Eingabe', all_districts: 'true')}&script_name=//evil.example&action=x"

    assert_redirected_to search_path(district: nil, q: 'Eingabe')
  end

  test 'GET show past the last page says so instead of finding nothing' do
    get search_path(district: districts(:hamburg_nord), q: 'Eingabe', page: 99)

    assert_response :success
    assert_includes @response.body, 'Diese Seite gibt es nicht.'
    assert_not_includes @response.body, 'Keine Drucksachen'
  end

  test 'GET show with a topic keeps to the Drucksachen even when the minutes tab is asked for' do
    get search_path(district: districts(:hamburg_nord), q: 'Eingabe', topic: 'radverkehr', tab: 'protokolle')

    assert_select '.nav-link.active', text: /Drucksachen/
  end

  test 'GET show offers the Stadtteil, street or topic the term names' do
    Quarter.reset!
    get search_path(district: districts(:hamburg_nord), q: 'Heilwigstraße')

    assert_select 'section[aria-label="Direkte Treffer"]', text: /Straße.*Heilwigstraße.*Barmbek-Nord/m
  ensure
    Quarter.reset!
  end

  test 'GET show lists minutes on their own tab' do
    meeting = districts(:hamburg_nord).meetings.create!(title: 'Sitzung', date: Date.new(2024, 3, 1), allris_id: 4711)
    meeting.agenda_items.create!(number: 'Ö 4', title: 'Verschiedenes', minutes: 'Der Quokkaweg wurde besprochen.')

    get search_path(district: districts(:hamburg_nord), q: 'Quokkaweg', tab: 'protokolle')

    assert_response :success
    assert_select '.nav-link.active', text: /Protokolle\s*1/
    assert_select '.list-group-item', text: /Verschiedenes.*Protokoll, TOP Ö 4/m
  end

  test 'GET show opens the minutes when only they have results' do
    meeting = districts(:hamburg_nord).meetings.create!(title: 'Sitzung', date: Date.new(2024, 3, 1), allris_id: 4711)
    meeting.agenda_items.create!(number: 'Ö 4', title: 'Verschiedenes', minutes: 'Der Quokkaweg wurde besprochen.')

    get search_path(district: districts(:hamburg_nord), q: 'Quokkaweg')

    assert_select '.nav-link.active', text: /Protokolle/
    # Opened only for want of Drucksachen, the tab is not carried to another Bezirk.
    assert_select 'nav[aria-label=Bezirke] a[href*=tab]', 0
  end

  test 'GET show with a topic offers it to clear and leaves out the minutes tab' do
    documents(:document_7).update_columns(topics: %w[radverkehr]) # rubocop:disable Rails/SkipsModelValidations
    get search_path(district: districts(:hamburg_nord), q: 'Eingabe', topic: 'radverkehr')

    assert_select '.badge', text: /Thema: Radverkehr/
    assert_select 'span.nav-link.disabled', text: /Protokolle/
    assert_select 'a.list-group-item.active', text: /Radverkehr/
  end

  test 'GET show counts the topics of the results beside them' do
    Document.update_all(topics: [])
    documents(:document_7).update_columns(topics: %w[radverkehr]) # rubocop:disable Rails/SkipsModelValidations
    get search_path(district: districts(:hamburg_nord), q: 'Eingabe')

    assert_select 'a.list-group-item', text: /Radverkehr\s*1/
  end

  test 'GET show says when nothing is found and how to find more' do
    get search_path(district: districts(:hamburg_nord), q: 'Xylophonkonzert')

    assert_response :success
    assert_includes @response.body, 'Keine Drucksachen zu „Xylophonkonzert“ in Hamburg-Nord.'
    assert_select 'a', text: 'Auch in Anhängen suchen'
  end
end
