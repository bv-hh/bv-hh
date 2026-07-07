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
end
