# frozen_string_literal: true

# The configurable RSS feed and the page that builds its URL.
#
# There is no subscription record: the selection lives entirely in the query
# string, so /feed renders both the empty form and the configured state, and the
# resulting .rss URL is the whole subscription. Nothing personal is stored.
class FeedsController < ApplicationController
  # Bump when the RSS template changes shape, so cached copies are refetched.
  FEED_VERSION = 1

  before_action :without_district
  # ahoy.track writes a row per request, including the 304s that feed readers
  # generate by the thousand. Tracking them would cost more than rendering.
  skip_after_action :track_event, if: -> { request.format.rss? }

  def show
    @query = FeedQuery.from_params(params)
    @documents = @query.relation.to_a

    respond_to do |format|
      format.html { show_html }
      format.rss { show_rss }
    end
  end

  private

  def show_html
    @title = 'RSS-Feed für Drucksachen aus Ihrem Stadtteil'
    # The URL space is combinatorial — it must never be crawled.
    @noindex = true
    @quarters = quarters_by_district
  end

  # [label, quarters] pairs, grouped by Bezirk and ordered by District#order
  # so the list matches the Bezirk order used everywhere else in the app.
  # Grouping on the register's Bezirk number rather than its name, because the
  # name is only a label and nothing joins on it.
  def quarters_by_district
    grouped = Quarter.by_name.group_by(&:bezirk)

    ordered = District.by_order.filter_map do |district|
      quarters = grouped.delete(district.bezirk_number)
      [district.name, quarters] if quarters.present?
    end

    # Anything whose Bezirk has no District record still filters correctly, so
    # keep it rather than silently dropping the option.
    ordered + grouped.values.map { |quarters| [quarters.first.bezirk_name, quarters] }
  end

  def show_rss
    expires_in 15.minutes, public: true
    # last_modified comes from the already-loaded collection: the relation is
    # ordered created_at DESC, so its first row is the maximum. A separate
    # MAX() probe would be slower than the feed query itself, because it cannot
    # stop early the way ORDER BY ... LIMIT does.
    fresh_when(etag: [FEED_VERSION, @query.cache_key, @documents.map(&:id)],
               last_modified: @documents.first&.created_at,
               public: true)
  end
end
