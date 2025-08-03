# frozen_string_literal: true

class Api::V1::DocumentsController < Api::V1::BaseController
  SEARCH_LIMIT = 25

  def show
    @document = Document.complete.find(params[:id])
    render json: document_json(@document)
  end

  def search
    term = (params[:q] || '').strip
    
    if term.blank?
      return render_error('Search term cannot be empty')
    end

    documents_query = build_documents_query(term)
    documents = documents_query.limit(SEARCH_LIMIT)

    render json: {
      documents: documents.map { |doc| document_json(doc) }
    }
  end

  private

  def document_json(document)
    {
      id: document.id,
      number: document.number,
      title: document.title,
      kind: document.kind,
      author: document.author,
      content: document.content,
      resolution: document.resolution,
      attached: document.attached,
      created_at: document.created_at,
      updated_at: document.updated_at,
      district: {
        id: document.district.id,
        name: document.district.name
      },
      meetings: document.meetings.map do |meeting|
        {
          id: meeting.id,
          title: meeting.title,
          date: meeting.date,
          start_time: meeting.start_time,
          end_time: meeting.end_time
        }
      end
    }
  end

  def build_documents_query(term)
    order = params[:order] == 'relevance' ? :relevance : :date
    attachments = params[:attachments] == 'true'
    kind = params[:kind].presence
    
    district = District.lookup!(params[:district]) if params[:district].present?

    documents_root = district.present? ? district.documents : Document.all
    documents_root = documents_root.complete.include_meetings
    documents_root = documents_root.where(kind: kind) if kind
    documents_root = documents_root.joins(:attachments) if attachments

    Document.search(term, root: documents_root, order: order, attachments: attachments)
  end
end