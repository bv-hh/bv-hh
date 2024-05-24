# frozen_string_literal: true

class CalendarsController < ApplicationController
  def show
    @date = begin
      Date.new(params[:year].to_i, params[:month].to_i, 1)
    rescue
      nil
    end || Time.zone.today.beginning_of_month
    @meetings = (@district&.meetings || Meeting.all).includes(:district, :committee)

    @years = (@meetings.minimum(:date).year..@meetings.maximum(:date).year)
    @date = Date.new(@years.first, 1, 1) unless @years.include?(@date.year)

    ordering = @district ? Committee.by_order : District.by_order
    @meetings = @meetings.joins(:district).in_month(@date).merge(ordering).group_by(&:date)

    render @district ? :show_for_district : :show
  end
end
