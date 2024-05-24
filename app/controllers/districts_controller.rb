# frozen_string_literal: true

class DistrictsController < ApplicationController
  def show
    redirect_to root_with_district_path(district: District.first) and return if @district.nil?

    @title = "Übersicht zur Bezirkspolitik in #{@district.name}: Bezirksversammlung, Gremien, Drucksachen und Termine"

    @documents = @district.documents.complete.latest_first.limit(10)
    @meetings = @district.meetings.complete.recent.latest_first.limit(10)
  end
end
