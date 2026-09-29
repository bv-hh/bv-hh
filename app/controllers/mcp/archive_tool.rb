# frozen_string_literal: true

class Mcp::ArchiveTool < Mcp::ApplicationTool
  DEFAULT_DAYS_AGO = 30
  MAX_DAYS_AGO = 365
  TYPES = %w[small_inquiries large_inquiries proposals]

  description <<~MD
    Retrieve a list of documents based on certain filter criteria.
  MD

  input_schema(
    properties: {
      days_ago: { type: 'number', description: "Since how many days ago documents should be included in the result. Defaults to #{DEFAULT_DAYS_AGO} days, clamped to #{MAX_DAYS_AGO}." },
      types: { type: 'string', description: "A comma-separated list of document types to include in the result. Valid values include #{TYPES.join(' ,')}" },
      district: { type: 'string', description: 'An optional district to restrict the list to. One of Hamburg-Mitte, Altona, Eimsbüttel, Hamburg-Nord, Wandsbek, Bergedorf, Harburg' },
      party: { type: 'string', description: 'An optional authoring party of a document, somthing like CDU, SPD, Grüne, Volt or Linke' },
      topic: TOPIC_INPUT,
    }
  )

  output_schema(
    properties: {
      documents: {
        type: 'array',
        description: 'Documents according to filter criteria',
        items: {
          type: 'object',
          properties: {
            id: { type: 'number', description: 'The unique identifier for the document' },
            number: { type: 'string', description: 'The reference number assigned to the document' },
            title: { type: 'string', description: 'The title of the document' },
            topics: TOPICS_OUTPUT,
          },
        },
      },
    }
  )

  annotations(
    title: 'Document archive tool',
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true
  )

  def self.call(days_ago: DEFAULT_DAYS_AGO, types: '', district: nil, party: nil, topic: nil)
    if district.present?
      district = District.lookup(district)
      return error_response('Invalid district provided.') if district.blank?
    end

    if topic.present?
      topic = Topic.lookup(topic)
      return error_response('Invalid topic provided.') if topic.blank?
    end

    documents = filter(Document.complete.in_last_days([days_ago.to_i, MAX_DAYS_AGO].min), district:, types:, party:, topic:)
    documents = documents.distinct.pluck(:id, :number, :title, :topics).map do |id, number, title, topics|
      { id:, number:, title:, topics: }
    end

    MCP::Tool::Response.new(
      [{ type: 'text', text: { documents: documents }.to_json }],
      structured_content: { documents: documents.as_json }
    )
  end

  def self.filter(documents, district:, types:, party:, topic:)
    documents = documents.where(district: district) if district

    types.split(',').each do |type|
      documents = documents.public_send(type.to_sym) if TYPES.include?(type)
    end

    documents = documents.authored_by(party) if party.present?
    topic ? documents.with_topics(topic.key) : documents
  end
end
