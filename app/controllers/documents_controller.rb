class DocumentsController < ApplicationController

  MAX_SUGGESTIONS = 10

  def index
    @documents = @district.documents.latest_first.page(params[:page])
  end

  def show
    @document = @district.documents.find(params[:id]&.split('-')&.last)
  end

  def search
    @term = params[:q] || ''

    if document = @district.documents.find_by(number: @term)
      redirect_to document_path(document) and return
    end

    @documents = Document.search(@term, @district.documents).page(params[:page])
  end

  def suggest
    documents = Document.prefix_search(params[:q], @district.documents).limit(MAX_SUGGESTIONS).load
    documents = documents.map do |article|
      {
        id: document.id,
        path: document_path(document),
        title: document.title,
        number: document.number
      }
    end
    render json: articles
  end
end
