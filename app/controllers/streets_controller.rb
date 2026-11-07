# frozen_string_literal: true

# Autocomplete for the feed's street picker and the map's search. ~9500
# streets is far too many to render as a select, so both query this as you
# type. positions are where the map zooms to: the pins of the street's
# Locations where Drucksachen name it, else the register's points, one per
# street of that name (a name can be a street in several Bezirke). The two can
# lie some way apart, and the map should circle its own pin.
class StreetsController < ApplicationController
  MAX_SUGGESTIONS = 10

  before_action :without_district
  skip_after_action :track_event

  def suggest
    render json: suggestions
  end

  private

  def suggestions
    term = Street.normalize(params[:q].to_s)
    return [] if term.blank?

    # Grouped by name, not by row: a street name recurring in several Bezirke is
    # one choice for the user, since selecting it means "whenever this street is
    # mentioned" regardless of boundaries.
    matches = Street.where('normalized_name LIKE ?', "#{Street.sanitize_sql_like(term)}%")
                    .order(:name)
                    .limit(MAX_SUGGESTIONS * 20)
                    .group_by(&:name)
                    .first(MAX_SUGGESTIONS)
    pins = Location.where(name: matches.map(&:first)).where.not(latitude: nil).group_by(&:name)

    matches.map do |name, streets|
      { name:, quarters: streets.flat_map(&:quarters).uniq.sort, positions: positions(pins[name] || streets) }
    end
  end

  def positions(places)
    places.filter_map { |place| [place.latitude, place.longitude] if place.latitude }
  end
end
