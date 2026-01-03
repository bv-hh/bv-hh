# frozen_string_literal: true

class Mcp::ApplicationTool < MCP::Tool
  def self.error_response(message)
    MCP::Tool::Response.new(
      [{ type: 'text', text: message }],
      structured_content: { error: { message: message } }
    )
  end

  def self.strip_tags(content)
    ActionController::Base.helpers.strip_tags(content)
  end
end
