# frozen_string_literal: true

class DocumentsController < ApplicationController
  include ActionView::Helpers::TextHelper

  skip_after_action :track_event, only: :suggest

  MAX_SUGGESTIONS = 5

  def index
    @documents = @district.documents.complete.include_meetings.latest_first.page(params[:page])
    @title = "Drucksachen der Bezirksversammlung #{@district.name} und ihrer Gremien"
  end

  def show
    @document = Document.complete.find(params[:id]&.split('-')&.last)
    full_document_path = document_path(@document, district: @document.district)
    redirect_to(full_document_path, status: :moved_permanently) and return unless request.path == full_document_path

    @title = "#{@document.number} - #{helpers.strip_tags(@document.title)&.squish&.truncate(50)} - #{@district.name}"
    @meta_description = helpers.strip_tags(@document.content)&.squish&.truncate(150)
    @noindex = @document.noindex
  end

  def allris
    redirect_to root_path and return if @district.blank?

    @document = @district.documents.find_by!(allris_id: params[:allris_id])
    redirect_to(document_path(@document, district: @document.district))
  end

  def suggest
    root = @district&.documents || Document.all
    documents = Document.prefix_search(params[:q], root.includes(:district)).limit(MAX_SUGGESTIONS).load
    documents = documents.map do |document|
      {
        id: document.id,
        path: document_path(document),
        title: document.title,
        number: document.number,
        district: document.district.name,
        kind: document.kind,
        excerpt: excerpt(strip_tags(document.full_text), params[:q], radius: 50),
      }
    end
    render json: documents
  end
end
