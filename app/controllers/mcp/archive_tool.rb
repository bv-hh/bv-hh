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

  def self.call(days_ago: DEFAULT_DAYS_AGO, types: '', district: nil, party: nil)
    if district.present?
      district = District.lookup(district)
      return error_response('Invalid district provided.') if district.blank?
    end

    days_ago = [days_ago.to_i, MAX_DAYS_AGO].min

    documents = Document.complete.in_last_days(days_ago)
    documents = documents.where(district: district) if district

    types.split(',').each do |type|
      documents = documents.public_send(type.to_sym) if TYPES.include?(type)
    end

    documents = documents.authored_by(party) if party.present?
    documents = documents.pluck(:id, :number).map { { id: it.first, number: it.last } }

    MCP::Tool::Response.new(
      [{ type: 'text', text: { documents: documents }.to_json }],
      structured_content: { documents: documents.as_json }
    )
  end
end
