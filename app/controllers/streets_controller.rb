# frozen_string_literal: true

# Autocomplete for the feed's street picker. ~9500 streets is far too many to
# render as a select, so the config page queries this as you type.
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
    Street.where('normalized_name LIKE ?', "#{Street.sanitize_sql_like(term)}%")
          .order(:name)
          .limit(MAX_SUGGESTIONS * 20)
          .group_by(&:name)
          .first(MAX_SUGGESTIONS)
          .map { |name, streets| { name: name, quarters: streets.flat_map(&:quarters).uniq.sort } }
  end
end
