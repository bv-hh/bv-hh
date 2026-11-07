# frozen_string_literal: true

require 'test_helper'

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  test 'GET index' do
    get documents_path(district: districts.first)
    assert_response :success
  end

  test 'GET show' do
    documents.each do |document|
      get document_path(document.id)
      assert_redirected_to document_path(document, district: document.district)

      get document_path(document, district: document.district)
      assert_response :success
    end
  end

  test 'GET show leads from Hamburg through the Bezirk and its Drucksachen to the document' do
    document = documents(:document_7)
    district = document.district

    get document_path(document, district:)

    assert_select 'nav[aria-label=Brotkrumen] li', 4
    assert_select 'nav[aria-label=Brotkrumen] a[href=?]', root_with_district_path(district:), text: district.name
    assert_select 'nav[aria-label=Brotkrumen] a[href=?]', documents_path(district:), text: 'Drucksachen'
    assert_select 'nav[aria-label=Brotkrumen] li[aria-current=page]', text: document.number
    assert_select 'h1', count: 1
  end

  test 'GET show lists the topics of the document' do
    document = documents(:document_7)
    document.update_columns(topics: %w[spielplaetze unbekannt]) # rubocop:disable Rails/SkipsModelValidations

    get document_path(document, district: document.district)

    assert_select '.card-header', text: /Themen/
    assert_select "a.rounded-pill[href='#{topic_path(topic: 'spielplaetze', district: document.district)}']", text: 'Spielplätze'
  end

  test 'GET allris redirects to the document' do
    document = documents(:document_7)
    get allris_documents_path(district: districts.first, allris_id: document.allris_id)
    assert_redirected_to document_path(document, district: document.district)
  end

  test 'GET allris without district redirects to root' do
    get allris_documents_path(allris_id: 1)
    assert_redirected_to root_path
  end

  test 'GET suggest returns json' do
    get suggest_documents_path(district: districts.first, q: 'Eingabe')
    assert_response :success
    assert_equal 'application/json', @response.media_type
    assert_kind_of Array, JSON.parse(@response.body)
  end
end
