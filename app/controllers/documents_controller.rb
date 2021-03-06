# frozen_string_literal: true

class DocumentsController < ApplicationController
  MAX_SUGGESTIONS = 10

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
  end

  def search
    @term = params[:q] || ''

    if @district.present? && (document = @district.documents.find_by(number: @term))
      redirect_to document_path(document) and return
    end

    set_search_options

    root = (@all_districts ? Document.all : @district.documents).complete.include_meetings

    root = root.where(kind: @kind) if @kind
    root = root.joins(:attachments) if @attachments

    @kinds = (@district.present? ? @district.documents.distinct.order(:kind).pluck(:kind) : [])

    @documents = Document.search(@term, root: root, order: @order, attachments: @attachments).page(params[:page])
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

  protected

  def set_search_options
    @order = :date if params[:order] == 'date'
    @order ||= :relevance

    @attachments = params[:attachments] == 'true'
    @all_districts = params[:all_districts] == 'true' || @district.blank?

    @kind = params[:kind] if params[:kind].present? && @kinds.include?(params[:kind])
  end
end
