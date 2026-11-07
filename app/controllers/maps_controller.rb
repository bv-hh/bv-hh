# frozen_string_literal: true

# The map of a district, or of all of Hamburg without one: where the
# Drucksachen of a time range (MapQuery) name places. Zoomed out it counts them
# per Bezirk or Stadtteil, zoomed in it pins the places, and beside it lists the
# Drucksachen in view (map_controller.js).
#
# The page itself is light. The shapes, the pins and the list each come from
# an action of their own, and a pin's popup only once it is opened.
class MapsController < ApplicationController
  # The list beside the map.
  PER_PAGE = 20

  before_action :reject_unknown_district
  before_action :set_query, except: :areas
  # Only the page is a visit. The rest follows every pan and zoom.
  skip_after_action :track_event, except: :show

  def show
    @title = "Karte der Bezirkspolitik in #{@district&.name || 'Hamburg'}"
    @meta_description = 'Welche Drucksachen der Bezirksversammlungen Orte in Ihrer Nähe betreffen – auf der Karte.'
    # Without a box (a district not yet located) the map starts on Hamburg and
    # fits the outlines once they are loaded.
    extent = @district ? @district.bounds : District.city_bounds
    @bounds = extent.flatten.compact.size == 4 ? extent : []
    @quarters = search_quarters
  end

  # The outlines of the Bezirke and Stadtteile. They only change with an import,
  # so browsers may keep them for a day.
  def areas
    expires_in 1.day, public: true

    data = Rails.cache.fetch(['map_areas', 2, @district], expires_in: 1.day) { area_data.to_json }
    render json: data
  end

  # Everything that depends on the time range and topic: the pins, the counts
  # per area, and how much of the range the map can show.
  def markers
    key = ['map_markers', 3, @district, @query.range, @query.topic&.key, Topic::VERSION, Date.current]
    data = Rails.cache.fetch(key, expires_in: 1.hour) do
      { places: @query.places, areas: @query.area_counts, counts: @query.counts }.to_json
    end

    render json: data
  end

  # The Drucksachen naming a place in the visible part of the map, for the
  # turbo frame beside it.
  def documents
    view = box
    scope = view ? @query.documents_within(**view) : @query.documents.none
    @documents = scope.for_list.page(params[:page]).per(PER_PAGE)

    render layout: false
  end

  # A pin's popup.
  def place
    @location = Location.find(params.expect(:location_id))
    documents = @query.documents_at(@location)
    @total = documents.count
    @documents = documents.for_list.limit(MapQuery::POPUP_DOCUMENTS)

    render partial: 'maps/popup', locals: { location: @location, documents: @documents, total: @total }
  end

  private

  # /map is all of Hamburg; /<anything else>/map is no page at all.
  def reject_unknown_district
    raise ActionController::RoutingError, "#{request.path}: no such district" if params[:district].present? && @district.nil?
  end

  def set_query
    @topic = Topic.lookup(params[:thema]) if params[:thema].present?
    @query = MapQuery.new(district: @district, range: params[:zeitraum], topic: @topic)
  end

  # south,west,north,east from ?bbox=, or nil when it is not four numbers.
  def box
    values = params[:bbox].to_s.split(',')
    return nil unless values.size == 4

    south, west, north, east = values.map { |value| Float(value) }
    { south:, west:, north:, east: }
  rescue ArgumentError
    nil
  end

  # The Bezirke (on the city map) or the district's own outline, and the
  # Stadtteile, each with its shape and label point ([lng, lat, radius]).
  def area_data
    districts = @district ? [District.by_number(@district.number)] : District.by_order.map { |d| District.by_number(d.number) }
    quarters = districts.flat_map { |district| Quarter.cached_in_district(district.number) }

    {
      districts: districts.select { |district| district.simplified_geometry.any? }.map do |district|
        { number: district.number, name: district.name, path: map_path(district:),
          polygons: district.simplified_geometry, label: district.label_point }
      end,
      quarters: quarters.map do |quarter|
        { name: quarter.name, district: quarter.district_number, path: quarter_path(district: quarter.district, quarter: quarter.slug),
          polygons: quarter.simplified_geometry, label: quarter.label_point }
      end,
    }
  end

  # Every Stadtteil for the search field, with its Bezirk and box. All of them
  # on a district's map too: a search ends where the place is.
  def search_quarters
    Quarter.by_name.select(:name, :slug, :district_number, :district_name, :min_lat, :min_lng, :max_lat, :max_lng)
           .filter_map do |quarter|
      next unless quarter.district && quarter.min_lat

      { name: quarter.name, district: quarter.district_name, path: quarter_path(district: quarter.district, quarter: quarter.slug),
        bounds: [[quarter.min_lat, quarter.min_lng], [quarter.max_lat, quarter.max_lng]] }
    end
  end
end
