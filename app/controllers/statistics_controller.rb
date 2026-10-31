# frozen_string_literal: true

class StatisticsController < ApplicationController
  # Categorical, in this order: one per line of a chart.
  SERIES_COLORS = %w[#2a78d6 #eb6834 #1baf7a #eda100 #e87ba4].freeze

  before_action :require_district

  def show
    @title = "Statistiken zur Bezirkspolitik in #{@district.name}"
    @statistics = DistrictStatistics.new(@district)
  end
end
