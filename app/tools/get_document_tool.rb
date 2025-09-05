# frozen_string_literal: true

class GetDocumentTool < ApplicationTool
  description "Get detailed information about a specific document by ID"

  arguments do
    required(:id).filled(:integer)
  end

  def call(id:)
    if id.blank?
      return text_response('Document ID is required')
    end

    host = request.host_with_port
    scheme = request.scheme
    url = "#{scheme}://#{host}/api/v1/documents/#{id}"

    text_response(<<~TEXT)
      API Call Details:
      URL: #{url}
      Method: GET

      This returns detailed information about document #{id}, including:
      - Full document metadata (id, number, title, kind, author)
      - Complete content and resolution text
      - Attachments information
      - District details
      - Associated meetings with dates and times  
      - Direct URL to the HTML view of the document
      
      The response will be in JSON format with all document fields populated.
    TEXT
  end
end