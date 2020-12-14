class DistrictsController < ApplicationController

  def show
    redirect_to root_with_district_path(district: District.first) and return if @district.nil?

    @documents = @district.documents.latest_first.limit(10)
    @meetings = @district.meetings.latest_first.limit(10)
  end
end
