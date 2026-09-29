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

  %i[imprint privacy about transparency mcp district_politics participation].each do |action|
    test "GET #{action}" do
      get send(:"#{action}_path")
      assert_response :success
    end
  end
end
