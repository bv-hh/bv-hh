# frozen_string_literal: true

require 'test_helper'

class Mcp::SearchToolTest < ActiveSupport::TestCase
  test 'call returns documents matching the query' do
    result = Mcp::SearchTool.call(query: 'Eingabe').structured_content

    assert_includes result[:documents].pluck(:number), '21-4776'
  end

  test 'call scopes results to a district when one is given' do
    result = Mcp::SearchTool.call(query: 'Eingabe', district: 'hamburg-nord').structured_content

    assert result[:documents].any?
    assert(result[:documents].all? { |doc| doc[:district] == 'Hamburg-Nord' })
  end

  test 'call returns empty result sets for a query that matches nothing' do
    result = Mcp::SearchTool.call(query: 'Xyzzykeinetreffer').structured_content

    assert_empty result[:documents]
    assert_empty result[:minutes]
  end

  test 'call filters by topic and returns the topics of each document' do
    Document.update_all(topics: [])
    documents(:document_7).update_columns(topics: %w[radverkehr]) # rubocop:disable Rails/SkipsModelValidations

    result = Mcp::SearchTool.call(query: 'Eingabe', topic: 'radverkehr').structured_content

    assert_equal ['21-4776'], result[:documents].pluck(:number)
    assert_equal [%w[radverkehr]], result[:documents].pluck(:topics)
    assert_empty result[:minutes]
  end

  test 'call rejects an unknown topic' do
    assert Mcp::SearchTool.call(query: 'Eingabe', topic: 'gibtsnicht').error?
  end
end
