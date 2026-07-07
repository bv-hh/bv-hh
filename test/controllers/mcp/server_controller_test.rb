# frozen_string_literal: true

require 'test_helper'

class Mcp::ServerControllerTest < ActionDispatch::IntegrationTest
  test 'POST index answers a JSON-RPC tools/list request' do
    post mcp_server_path,
         params: { jsonrpc: '2.0', id: 1, method: 'tools/list' }.to_json,
         headers: { 'Content-Type' => 'application/json' }

    assert_response :success
    assert_equal 'application/json', @response.media_type

    body = JSON.parse(@response.body)
    assert_not_empty body.dig('result', 'tools')
  end
end
