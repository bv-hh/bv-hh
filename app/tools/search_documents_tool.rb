# frozen_string_literal: true

class SearchDocumentsTool < ApplicationTool
  description "Search for documents in Hamburg district assemblies database"

  arguments do
    required(:q).filled(:string)
    optional(:district).maybe(:string)
    optional(:order).maybe(:string)
    optional(:attachments).maybe(:string)
    optional(:kind).maybe(:string)
  end

  def call(q:, district: nil, order: nil, attachments: nil, kind: nil)
    if q.blank?
      return text_response('Search term (q) is required and cannot be empty')
    end

    # Build the API URL
    host = request.host_with_port
    scheme = request.scheme
    base_url = "#{scheme}://#{host}/api/v1/documents/search"
    
    params = { q: q.strip }
    params[:district] = district if district.present?
    params[:order] = order if order.present?
    params[:attachments] = attachments if attachments.present?
    params[:kind] = kind if kind.present?
    
    full_url = "#{base_url}?#{params.to_query}"

    param_descriptions = []
    param_descriptions << "- district: \"#{district}\"" if district.present?
    param_descriptions << "- order: \"#{order}\"" if order.present?
    param_descriptions << "- attachments: \"#{attachments}\"" if attachments.present?
    param_descriptions << "- kind: \"#{kind}\"" if kind.present?

    text_response(<<~TEXT)
      API Call Details:
      URL: #{full_url}
      Method: GET
      Parameters:
      - q: "#{q}" (required)
      #{param_descriptions.join("\n")}

      This returns a JSON response with up to 25 documents matching your search criteria. Each document includes:
      - id, number, title, kind, author
      - content, resolution, attached
      - created_at, updated_at
      - url (full URL to HTML view)
      - district information
      - associated meetings with dates and times

      Available districts: #{District::ORDER.map(&:parameterize).join(', ')}
      
      Common document types:
      #{[Document::SMALL_INQUIRY_TYPES, Document::LARGE_INQUIRY_TYPES, Document::STATE_INQUIRY_TYPES].flatten.uniq.first(5).map { |type| "- #{type}" }.join("\n")}
    TEXT
  end
end