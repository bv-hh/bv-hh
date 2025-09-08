# frozen_string_literal: true

require 'test_helper'

class Api::V1::DocumentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @document = documents(:document_7)
    @district = districts(:hamburg_nord)
  end

  # SHOW ENDPOINT TESTS
  test 'GET show returns document as JSON' do
    get api_v1_document_path(@document.id), as: :json

    assert_response :success

    json_response = response.parsed_body

    assert_equal @document.id, json_response['id']
    assert_equal @document.number, json_response['number']
    assert_equal @document.title, json_response['title']
    assert_equal @document.kind, json_response['kind']
    if @document.author.nil?
      assert_nil json_response['author']
    else
      assert_equal @document.author, json_response['author']
    end
    assert_equal @document.content, json_response['content']
    assert_equal @document.resolution, json_response['resolution']
    assert_equal @document.attached, json_response['attached']

    # Check district information
    assert_equal @document.district.id, json_response['district']['id']
    assert_equal @document.district.name, json_response['district']['name']

    # Check meetings array
    assert_kind_of Array, json_response['meetings']

    # Ensure excluded fields are not present
    assert_nil json_response['full_text']
    assert_nil json_response['attachments']
    assert_nil json_response['extracted_locations']
    assert_nil json_response['locations_extracted_at']
  end

  test 'GET show returns 404 for non-existent document' do
    get api_v1_document_path(999999), as: :json

    assert_response :not_found

    json_response = response.parsed_body
    assert_includes json_response['error'], "Couldn't find Document"
  end

  test 'GET show returns 404 for non-public document' do
    # Create a non-public document fixture if needed
    non_public_doc = Document.create!(
      district: @district,
      number: 'TEST-001',
      title: 'Non-public document',
      content: 'Secret content',
      non_public: true,
      allris_id: 999999
    )

    get api_v1_document_path(non_public_doc.id), as: :json

    assert_response :not_found
  end

  # SEARCH ENDPOINT TESTS
  test 'GET search returns documents matching search term' do
    get search_api_v1_documents_path, params: { q: 'Heilwigstraße' }, as: :json

    assert_response :success

    json_response = response.parsed_body

    assert_kind_of Array, json_response['documents']

    # Check that results contain documents
    if json_response['documents'].any?
      document = json_response['documents'].first
      assert_kind_of Integer, document['id']
      assert_not_nil document['title']
      assert_not_nil document['district']
    end
  end

  test 'GET search returns empty results for non-matching term' do
    get search_api_v1_documents_path, params: { q: 'xyz123nonexistent' }, as: :json

    assert_response :success
    json_response = response.parsed_body

    assert_empty json_response['documents']
  end

  test 'GET search returns error for empty search term' do
    get search_api_v1_documents_path, params: { q: '' }, as: :json

    assert_response :bad_request
    json_response = response.parsed_body
    assert_equal 'Search term cannot be empty', json_response['error']
  end

  test 'GET search returns error for missing search term' do
    get search_api_v1_documents_path, as: :json

    assert_response :bad_request
    json_response = response.parsed_body
    assert_equal 'Search term cannot be empty', json_response['error']
  end

  test 'GET search respects order parameter' do
    get search_api_v1_documents_path, params: { q: 'Heilwigstraße', order: 'relevance' }, as: :json

    assert_response :success
    json_response = response.parsed_body
    assert_kind_of Array, json_response['documents']
  end

  test 'GET search respects attachments parameter' do
    get search_api_v1_documents_path, params: { q: 'Heilwigstraße', attachments: 'true' }, as: :json

    assert_response :success
    json_response = response.parsed_body
    assert_kind_of Array, json_response['documents']
  end

  test 'GET search respects kind parameter' do
    get search_api_v1_documents_path, params: { q: 'Heilwigstraße', kind: 'Mitteilungsvorlage Bezirksamt' }, as: :json

    assert_response :success
    json_response = response.parsed_body
    assert_kind_of Array, json_response['documents']
  end

  test 'GET search filters by district name' do
    get search_api_v1_documents_path, params: { q: 'Heilwigstraße', district: @district.to_param }, as: :json

    assert_response :success
    json_response = response.parsed_body
    assert_kind_of Array, json_response['documents']
  end

  test 'GET search returns 404 for non-existent district' do
    get search_api_v1_documents_path, params: { q: 'test', district: 'non-existent-district' }, as: :json

    assert_response :not_found
    json_response = response.parsed_body
    assert_includes json_response['error'], "Couldn't find District"
  end

  # PAGINATION TESTS
  test 'GET search returns limited results' do
    get search_api_v1_documents_path, params: { q: 'Hamburg' }, as: :json

    assert_response :success
    json_response = response.parsed_body

    assert_operator json_response['documents'].size, :<=, 25
  end
end
