# frozen_string_literal: true

class SearchController < ApplicationController
  PER_PAGE = 25

  # Searches offered below a hero search field. Evergreen terms that find
  # something in every district, not current affairs that go stale.
  EXAMPLES = ['Tempo 30', 'Spielplatz', 'Radweg', 'Baumfällung', 'Sondermittel'].freeze

  before_action :redirect_document_number, :redirect_all_districts, only: :show

  def show
    @hero_search = true
    @term = (params[:q] || '').strip
    @title = @term.present? ? "Suche nach „#{@term}“ — Bezirkspolitik in Hamburg" : 'Suche — Bezirkspolitik in Hamburg'
    set_search_options
    return if @term.blank?

    @matches = SearchMatches.new(@term)
    search_documents
    search_agenda_items
    count_districts
    page_open_tab
  end

  private

  def redirect_document_number
    document = @district&.documents&.find_by(number: params[:q].to_s.strip)
    redirect_to document_path(document) if document
  end

  # "Alle Bezirke" used to be a checkbox on the district's URL. It is the URL
  # without a district now, which old links are sent on to.
  def redirect_all_districts
    return unless @district.present? && params[:all_districts] == 'true'

    redirect_to search_path(district: nil, **request.query_parameters.except('all_districts').symbolize_keys)
  end

  def set_search_options
    @order = params[:order] == 'relevance' ? :relevance : :date
    @attachments = params[:attachments] == 'true'
    @kinds = Rails.cache.fetch(['document_kinds', @district&.id], expires_in: 1.hour) do
      (@district ? @district.documents : Document.all).complete.distinct.order(:kind).pluck(:kind).compact
    end
    @kind = params[:kind] if @kinds.include?(params[:kind])
    @topic = Topic.lookup(params[:topic]) if params[:topic].present?
    @filters = filters
  end

  # The query string of the current search, for links that change one part of
  # it. Tab and page are left out: any change starts at the first page.
  def filters
    { q: @term, kind: @kind, topic: @topic&.slug, attachments: ('true' if @attachments),
      order: ('relevance' if @order == :relevance) }.compact
  end

  def search_documents
    matching = documents_matching(@district ? @district.documents : Document.all)
    # Counted before the topic filter, so the other topics stay on offer.
    @topic_counts = Topic.ranked(Document.where(id: ids_of(matching)).topic_counts)
    matching = matching.with_topics(@topic.key) if @topic

    @documents = matching.preload(:district, meetings: :committee).page(1).per(PER_PAGE)
    @documents = @documents.preload(:attachments) if @attachments
  end

  def search_agenda_items
    root = (@district ? @district.agenda_items : AgendaItem.all).includes(meeting: %i[committee district])
    # Minutes carry no topics, so a topic filter leaves none of them.
    root = root.none if @topic

    @agenda_items = AgendaItem.minutes_prefix_search(@term, root).page(1).per(PER_PAGE)
  end

  # District id => results there, for the Bezirk links. The same filters as the
  # list, so the link to the current Bezirk shows the count below it. Cached
  # briefly: the minutes are matched by ILIKE in every Bezirk, which takes most
  # of a second for a common word, and the example searches recur.
  def count_districts
    key = ['search_district_counts', @term.downcase, @kind, @topic&.key, @attachments]
    @district_counts = Rails.cache.fetch(key, expires_in: 10.minutes) do
      documents = documents_matching(Document.all)
      documents = documents.with_topics(@topic.key) if @topic
      counts = Document.where(id: ids_of(documents)).group(:district_id).count
      unless @topic
        minutes = AgendaItem.minutes_prefix_search(@term).unscope(:order).group('meetings.district_id').count
        counts.merge!(minutes) { |_district, documents, agenda_items| documents + agenda_items }
      end
      counts
    end
  end

  def documents_matching(root)
    root = root.complete
    root = root.where(kind: @kind) if @kind
    Document.search(@term, root:, order: @order, attachments: @attachments)
  end

  # Document.search selects a ranking, which a subquery of ids has no use for.
  def ids_of(documents)
    documents.except(:select, :order).select('documents.id')
  end

  # The page asked for belongs to the tab that is open, which is only known
  # once both are counted.
  def page_open_tab
    @tab = open_tab
    if @tab == :documents
      @documents = @documents.page(params[:page]).per(PER_PAGE)
      @places = places_by_document
    else
      @agenda_items = @agenda_items.page(params[:page]).per(PER_PAGE)
    end
  end

  # Drucksachen unless asked otherwise, or when only the minutes have something.
  def open_tab
    return :minutes if params[:tab] == 'protokolle'
    return :documents if params[:tab].present?

    @documents.total_count.zero? && @agenda_items.total_count.positive? ? :minutes : :documents
  end

  # Document id => the places it mentions, those named in the term first.
  def places_by_document
    words = @term.downcase.split
    DocumentLocation.where(document_id: @documents.map(&:id)).includes(:location).group_by(&:document_id)
                    .transform_values do |links|
                      links.map(&:location).uniq(&:name).sort_by do |location|
                        [words.any? { |word| location.name.downcase.include?(word) } ? 0 : 1, location.name]
                      end
                    end
  end
end
