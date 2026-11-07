# frozen_string_literal: true

class Mcp::DocumentsTool < Mcp::ApplicationTool
  LINKED_DOCUMENT = {
    type: 'object',
    properties: {
      id: { type: 'number', description: 'The unique identifier of the document' },
      number: { type: 'string', description: 'The reference number of the document' },
      title: { type: 'string', description: 'The title of the document' },
    },
  }.freeze

  description <<~MD
    Retrieves a document for a district council based on its unique identifier or reference number.
      The document includes metadata such as title, date, type, and associated meeting and/or
      council information, the documents of the same district it refers to by number and those referring
      to it, and similar documents from any district, found by meaning rather than wording
      (useful to see whether a matter was raised elsewhere before). If the document cannot be found, an
      error message is returned.
      A district can be specified by name to narrow down the search when using a reference number, one of
      the following: Hamburg-Mitte, Altona, Eimsbüttel, Hamburg-Nord, Wandsbek, Bergedorf, Harburg.
  MD

  input_schema(
    properties: {
      identifier: { type: 'string', description: 'The unique identifier or reference number of the document.' },
      district: { type: 'string', description: 'The district to narrow down the document lookup. Only required if document is retrieved by its reference number.' },
    },
    required: %w[identifier]
  )

  output_schema(
    properties: {
      id: { type: 'number', description: 'The unique identifier for the document' },
      number: { type: 'string', description: 'The reference number assigned to the document' },
      title: { type: 'string', description: 'The title of the document' },
      kind: { type: 'string', description: 'The type/kind of the document' },
      content: { type: 'string', description: 'The content of the document' },
      resolution: { type: 'string', description: 'The resolution text of the document, if applicable' },
      attached: { type: 'string', description: 'Information of attached files if any' },
      district: { type: 'string', description: 'The name of the district the document belongs to' },
      topics: TOPICS_OUTPUT,
      outcome: OUTCOME_OUTPUT,
      meetings: { type: 'array', description: 'An array of meetings having this document on their agenda',
                  items: {
                    type: 'object',
                    properties: {
                      id: { type: 'number', description: 'The unique identifier of the meeting' },
                      title: { type: 'string', description: 'The title of the meeting' },
                      date: { type: 'string', description: 'The date of the meeting' },
                    },
                  } },
      referenced_documents: { type: 'array', description: 'Documents of the same district this one names by number',
                              items: LINKED_DOCUMENT },
      citing_documents: { type: 'array', description: 'Documents of the same district that name this one by number',
                          items: LINKED_DOCUMENT },
      similar_documents: { type: 'array', description: 'Documents close in meaning, from any district, closest first',
                           items: {
                             type: 'object',
                             properties: {
                               id: { type: 'number', description: 'The unique identifier of the document' },
                               number: { type: 'string', description: 'The reference number of the document' },
                               title: { type: 'string', description: 'The title of the document' },
                               district: { type: 'string', description: 'The district the document belongs to' },
                             },
                           } },
    }
  )

  annotations(
    title: 'Document retrieval tool',
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true
  )

  def self.call(identifier:, district: nil)
    if district.present?
      district = District.lookup(district)
      return error_response('Invalid district provided.') if district.blank?
    end

    documents = Document.complete.preload(:district, agenda_items: :meeting)
    document = if district.present?
      documents.find_by(district:, number: identifier)
    else
      documents.find_by(id: identifier)
    end

    return error_response('No document found with the provided identifier.') if document.blank?

    result = document.as_json.merge(linked(document))
    MCP::Tool::Response.new(
      [{ type: 'text', text: result.to_json }],
      structured_content: result
    )
  end

  def self.linked(document)
    links = document.links.slice(:referenced, :citing).transform_values do |documents|
      documents.pluck(:id, :number, :title).map { |id, number, title| { id:, number:, title: } }
    end
    {
      referenced_documents: links[:referenced],
      citing_documents: links[:citing],
      similar_documents: similar(document, exclude: links.values.flatten.pluck(:id)),
    }
  end

  def self.similar(document, exclude:)
    document.similar_documents(exclude:).map do |similar|
      { id: similar.id, number: similar.number, title: similar.title, district: similar.district.name }
    end
  end
end
