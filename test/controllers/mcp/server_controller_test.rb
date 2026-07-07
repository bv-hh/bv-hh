# frozen_string_literal: true

require 'test_helper'

class Mcp::ServerControllerTest < ActionDispatch::IntegrationTest
  def rpc(method, params = {})
    post mcp_server_path, params: { jsonrpc: '2.0', id: 1, method: method, params: params }.to_json,
                          headers: { 'Content-Type' => 'application/json' }
    assert_response :success
    response.parsed_body
  end

  test 'tools/list exposes the registered tools' do
    tools = rpc('tools/list').dig('result', 'tools')
    assert_equal %w[search_tool documents_tool archive_tool].sort, tools.pluck('name').sort
  end

  test 'tools/call runs the search tool' do
    result = rpc('tools/call', name: 'search_tool', arguments: { query: 'test' })['result']
    assert_not result['isError']
    assert result.key?('structuredContent')
  end

  test 'tools/call flags an error for an invalid district' do
    result = rpc('tools/call', name: 'documents_tool',
                               arguments: { identifier: '1', district: 'Nonexistent' })['result']
    assert result['isError']
    assert_equal 'Invalid district provided.', result.dig('content', 0, 'text')
  end
end
