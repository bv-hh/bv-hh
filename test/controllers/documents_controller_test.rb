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
end
