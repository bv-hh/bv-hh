# frozen_string_literal: true

class Mcp::ApplicationTool < MCP::Tool
  TOPIC_INPUT = {
    type: 'string',
    enum: Topic.keys,
    description: 'Optional: restrict to documents tagged with this topic. Topics are assigned automatically and ' \
                 "can be incomplete. #{Topic.map { |topic| "#{topic.key} = #{topic.label}" }.join(', ')}",
  }.freeze

  TOPICS_OUTPUT = { type: 'array', items: { type: 'string' }, description: 'Keys of the topics the document is tagged with' }.freeze

  def self.error_response(message)
    MCP::Tool::Response.new(
      [{ type: 'text', text: message }],
      error: true,
      structured_content: { error: { message: message } }
    )
  end

  def self.strip_tags(content)
    ActionController::Base.helpers.strip_tags(content)
  end
end
