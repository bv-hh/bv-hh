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
end
