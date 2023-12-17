# frozen_string_literal: true

class SearchController < ApplicationController

  def show
    @term = (params[:q] || '').strip

    if @district.present? && (document = @district.documents.find_by(number: @term))
      redirect_to document_path(document) and return
    end

    @kinds = (@district.present? ? @district.documents.distinct.order(:kind).pluck(:kind) : [])

    set_search_options

    root = (@all_districts ? Document.all : @district.documents).complete.include_meetings

    root = root.where(kind: @kind) if @kind
    root = root.joins(:attachments) if @attachments

    @documents = Document.search(@term, root:, order: @order, attachments: @attachments).page(params[:page])
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
