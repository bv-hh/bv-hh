# frozen_string_literal: true

# A page per topic, in one district (/hamburg-nord/themen/radverkehr) or across
# Hamburg (/themen/radverkehr). Built like the Quarter page, on the same
# FeedQuery, so the list and its RSS feed are the same selection.
class TopicsController < ApplicationController
  PER_PAGE = 25

  def show
    @topic = Topic.lookup(params[:topic])
    raise ActiveRecord::RecordNotFound if @topic.blank?

    # Also catches an unknown district segment, which lookup_district leaves nil.
    redirect_to(canonical_path, status: :moved_permanently) and return unless request.path == canonical_path

    @query = FeedQuery.new(district: @district, topics: [@topic.key])
    # Numbers run in sequence within one district only, so across Hamburg the
    # order is created_at, as on the Quarter page and in the feed.
    @documents = @query.relation(limit: nil, order: @district ? :number : :created_at)
                       .page(params[:page]).per(PER_PAGE)
                       .preload(:district, meetings: :committee)
    set_counts
    set_meta
  end

  private

  def set_counts
    @district_counts = Document.complete.with_topics(@topic.key).group(:district_id).count
    # The same counts as the district page, so "Weitere Themen" links only to
    # topics that have documents here.
    @topic_counts = cached_topic_counts(:district, @district&.id) { @district ? @district.documents.complete : Document.complete }
  end

  def set_meta
    @title = "#{@topic.label} — Drucksachen #{@district ? "aus #{@district.name}" : 'aus allen Hamburger Bezirken'}"
    @meta_description = "Aktuelle Drucksachen der #{@district ? "Bezirksversammlung #{@district.name}" : 'Hamburger Bezirksversammlungen'} " \
                        "zum Thema #{@topic.label}."
    # A topic nobody has written about here is not worth a search result.
    @noindex = true if @documents.empty?
  end

  def canonical_path
    @canonical_path ||= topic_path(topic: @topic, district: @district&.to_param)
  end
end
