# frozen_string_literal: true

class SearchController < ApplicationController

  LIMIT = 25

  def show
    @term = (params[:q] || '').strip

    if @district.present? && (document = @district.documents.find_by(number: @term))
      redirect_to document_path(document) and return
    end

    @kinds = (@district.present? ? @district.documents.distinct.order(:kind).pluck(:kind) : [])

    set_search_options

    documents_root = (@all_districts ? Document.all : @district.documents).complete.include_meetings

    documents_root = documents_root.where(kind: @kind) if @kind
    documents_root = documents_root.joins(:attachments) if @attachments

    @documents = Document.search(@term, root: documents_root, order: @order, attachments: @attachments)
    @more_documents = [@documents.count(:all) - LIMIT, 0].max
    @documents = @documents.limit(LIMIT)

    agenda_items_root = (@all_districts ? AgendaItem.all : @district.agenda_items).includes(:meeting)

    @agenda_items = AgendaItem.minutes_prefix_search(@term, agenda_items_root)
    @more_agenda_items = [@agenda_items.count - LIMIT, 0].max
    @agenda_items = @agenda_items.limit(LIMIT)
  end

 protected

  def set_search_options
    @order = :relevance if params[:order] == 'relevance'
    @order ||= :date

    @attachments = params[:attachments] == 'true'
    @all_districts = params[:all_districts] == 'true' || @district.blank?

    @kind = params[:kind] if params[:kind].present? && @kinds.include?(params[:kind])
  end
end
