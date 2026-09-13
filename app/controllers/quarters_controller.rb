# frozen_string_literal: true

# A page per Quarter, listing the Drucksachen that mention a location in it,
# with the matching single-Quarter RSS feed alongside.
#
# Same FeedQuery as the configurable feed, just with one Quarter selected.
class QuartersController < ApplicationController
  PER_PAGE = 25

  skip_after_action :track_event, if: -> { request.format.rss? }

  def show
    @quarter = Quarter.lookup(params[:quarter])
    # Without a District there is no canonical URL to redirect to, so a
    # Quarter in a district that has not been onboarded is simply not a page.
    raise ActiveRecord::RecordNotFound if @quarter.blank? || @quarter.district.blank?

    redirect_to(canonical_path, status: :moved_permanently) and return unless request.path == canonical_path

    @query = FeedQuery.new(quarters: [@quarter.name])

    respond_to do |format|
      format.html { show_html }
      format.rss { show_rss }
      format.json { render json: map_data }
    end
  end

  private

  # Feeds the map beside the listing. Only the locations of the documents on the
  # current page, so the map always shows exactly what the list shows.
  def map_data
    {
      boundary: @quarter.geometry,
      bounds: [[@quarter.min_lat, @quarter.min_lng], [@quarter.max_lat, @quarter.max_lng]],
      markers: markers,
    }
  end

  def markers
    document_locations = DocumentLocation.joins(:location)
                                         .where(document_id: page_documents.map(&:id))
                                         .where('locations.quarters @> ARRAY[?]::varchar[]', @quarter.name)
                                         .includes(:location, document: :district)

    document_locations.group_by(&:location).map do |location, entries|
      {
        position: [location.latitude, location.longitude],
        name: location.name,
        address: location.formatted_address,
        path: location_path(location, district: location.district),
        documents: entries.map(&:document).uniq.first(10).map do |document|
          { number: document.number, title: document.title, path: document_path(document, district: document.district) }
        end,
      }
    end
  end

  def page_documents
    @page_documents ||= @query.relation(limit: nil, order: :number).page(params[:page]).per(PER_PAGE)
  end

  # A Quarter belongs to exactly one district, so there is exactly one correct
  # URL for it — /altona/langenhorn redirects to /hamburg-nord/langenhorn.
  def canonical_path
    # Keep whatever format was asked for, or the redirect would bounce
    # /x.json and /x.rss back to the HTML page forever.
    @canonical_path ||= quarter_path(district: @quarter.district, quarter: @quarter.slug,
                                     format: request.format.html? ? nil : request.format.symbol)
  end

  def show_html
    @title = "Drucksachen zu #{@quarter.name} — Bezirkspolitik in Hamburg"
    @meta_description = "Aktuelle Drucksachen der Bezirksversammlung, die Orte in #{@quarter.name} erwähnen."
    # latest_first (document number) rather than created_at, to match every
    # other listing in the app; the feed keeps created_at.
    @documents = page_documents.preload(:district, meetings: :committee)
  end

  def show_rss
    @documents = @query.relation.to_a

    expires_in 15.minutes, public: true
    fresh_when(etag: [FeedsController::FEED_VERSION, @query.cache_key, @documents.map(&:id)],
               last_modified: @documents.first&.created_at,
               public: true)
    # fresh_when already rendered 304 for a conditional request; rendering
    # again here would raise DoubleRenderError.
    render 'feeds/show' unless performed?
  end
end
