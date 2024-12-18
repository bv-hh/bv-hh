# frozen_string_literal: true

class LocationsController < ApplicationController
  def show
    @location = Location.find(params[:id]&.split('-')&.last)

    full_location_path = location_path(@location, district: @location.district)
    redirect_to(full_location_path, status: :moved_permanently) and return unless request.path == full_location_path

    @documents = @location.documents.complete.include_meetings.latest_first.page(params[:page])

    @title = "#{@location.name} - #{@location.formatted_address}"
  end
end
