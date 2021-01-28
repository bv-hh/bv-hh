# frozen_string_literal: true

class DocumentsController < ApplicationController
  MAX_SUGGESTIONS = 10

  def index
    @documents = @district.documents.complete.include_meetings.latest_first.page(params[:page])
  end

  def show
    @document = @district.documents.complete.find(params[:id]&.split('-')&.last)
    redirect_to(document_path(@document), status: :moved_permanently) and return unless request.path == document_path(@document)
  end

  def search
    @term = params[:q] || ''

    if (document = @district.documents.find_by(number: @term))
      redirect_to document_path(document) and return
    end

    @kinds = @district.documents.distinct.order(:kind).pluck(:kind)

    root = @district.documents.complete.include_meetings

    if params[:kind].present?
      @kind = params[:kind]
      root = root.where(kind: @kind)
    end

    @ordering = :date if params[:ordering] == 'date'
    @ordering ||= :relevance

    @documents = Document.search(@term, root, @ordering).page(params[:page])
  end

  def suggest
    documents = Document.prefix_search(params[:q], @district.documents).limit(MAX_SUGGESTIONS).load
    documents = documents.map do |_article|
      {
        id: document.id,
        path: document_path(document),
        title: document.title,
        number: document.number,
      }
    end
    render json: documents
  end
end
