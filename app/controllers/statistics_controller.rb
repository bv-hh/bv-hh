# frozen_string_literal: true

# A district's statistics, or all of Hamburg's at /statistics.
class StatisticsController < ApplicationController
  # Categorical, in this order: one per line of a chart.
  SERIES_COLORS = %w[#2a78d6 #eb6834 #1baf7a #eda100 #e87ba4].freeze

  before_action :reject_unknown_district

  def show
    if @district
      @title = "Statistiken zur Bezirkspolitik in #{@district.name}"
      @statistics = DistrictStatistics.new(@district)
    else
      @title = 'Statistiken zur Bezirkspolitik in Hamburg'
      @statistics = CityStatistics.new
    end
  end

  private

  # /statistics is all of Hamburg; /<anything else>/statistics is no page at
  # all, rather than a copy of it.
  def reject_unknown_district
    raise ActionController::RoutingError, "#{request.path}: no such district" if params[:district].present? && @district.nil?
  end
end
