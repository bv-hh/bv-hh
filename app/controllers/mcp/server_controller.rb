# frozen_string_literal: true

class Mcp::ServerController < ApplicationController
  skip_forgery_protection

  MCP.configure do |config|
    config.exception_reporter = lambda { |exception, server_context|
      exception = exception.cause
      return if exception.blank?

      Rails.logger.error { "MCP EXCEPTION: #{exception.message}\n#{exception.backtrace.join("\n")}\nSERVER CONTEXT: #{server_context&.inspect}" }
    }
  end

  def index
    server = MCP::Server.new(
      name: 'BV-HH',
      title: 'Access public documents of all local district concils of the city of Hamburg. ',
      version: '0.0.1',
      instructions: 'Ask something about a district, a committee, a meeting or an agenda.',
      tools: [
        Mcp::SearchTool,
        Mcp::DocumentsTool,
      ],
      prompts: []
    )
    response = server.handle_json(request.body.read)

    Rails.logger.debug { "MCP RESPONSE: #{response.inspect}" }

    render json: response
  end
end
