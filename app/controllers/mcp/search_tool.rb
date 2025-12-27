# frozen_string_literal: true

class Mcp::SearchTool < Mcp::ApplicationTool
  LIMIT = 5

  description <<~MD
    Searches for documents and meeting minutes based on a query string.
  MD

  input_schema(
    properties: {
      query: { type: 'string', description: 'The query string to search for' },
      district: { type: 'string', description: 'Optional: a district to limit the search to' },
    },
    required: ['query']
  )

  output_schema(
    properties: {
      documents: {
        type: 'array',
        description: 'Document results matching the search query, limited to 25 results',
        items: {
          type: 'object',
          properties: {
            id: { type: 'number', description: 'The unique identifier for the document' },
            number: { type: 'string', description: 'The reference number assigned to the document' },
            title: { type: 'string', description: 'The title of the document' },
            kind: { type: 'string', description: 'The type/kind of the document' },
            content: { type: 'string', description: 'The content of the document' },
            resolution: { type: 'string', description: 'The resolution text of the document, if applicable' },
            attached: { type: 'string', description: 'Information of attached files if any' },
            district: { type: 'string', description: 'The name of the district the document belongs to' },
            meetings: { type: 'array', description: 'An array of meetings having this document on their agenda',
                        items: {
                          type: 'object',
                          properties: {
                            id: { type: 'number', description: 'The unique identifier of the meeting' },
                            title: { type: 'string', description: 'The title of the meeting' },
                            date: { type: 'string', description: 'The date of the meeting' },
                          },
                        } },
          },
        },
      },
      minutes: {
        type: 'array',
        description: 'Agenda items with meeting minutes matching the search query, limited to 25 results',
        items: {
          type: 'object',
          properties: {
            id: { type: 'number', description: 'The unique identifier for the agenda item' },
            meeting_id: { type: 'number', description: 'The unique identifier for the associated meeting' },
            document_id: { type: %w[number null], description: 'The unique identifier for the associated document, if any' },
            title: { type: 'string', description: 'The title of the agenda item' },
            number: { type: 'string', description: 'The  number of the agenda item determining its order for the meeting' },
            minutes: { type: 'string', description: 'The minutes text of the agenda item' },
            decision: { type: %w[string null], description: 'The decision text of the agenda item' },
          },
        },
      },
    }
  )

  annotations(
    title: 'Search tool for documents and meeting minutes',
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true
  )

  def self.call(query:, district: nil)
    term = (query || '').strip
    district = District.lookup(district || '')
    documents_root = (district ? district.documents : Document.all).complete.include_meetings
    agenda_items_root = (district ? district.agenda_items : AgendaItem.all).includes(:meeting)

    documents = Document.search(term, root: documents_root).limit(LIMIT)
    minutes = AgendaItem.minutes_prefix_search(term, agenda_items_root).limit(LIMIT)

    documents_result = documents.map(&:as_json)
    minutes_result = minutes.map(&:as_json)

    result = { documents: documents_result, minutes: minutes_result }

    MCP::Tool::Response.new(
      [{ type: 'text', text: result.to_json }],
      structured_content: result
    )
  end
end
