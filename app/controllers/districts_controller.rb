# frozen_string_literal: true

class DistrictsController < ApplicationController
  def show
    if @district.nil?
      # /langenhorn is a Quarter, not a district: the route above matches the
      # single-segment form first, so send it on to its canonical two-segment
      # URL rather than dumping the visitor on an arbitrary district.
      quarter = Quarter.lookup(params[:district])
      if quarter.present? && quarter.district.present?
        redirect_to(quarter_path(district: quarter.district, quarter: quarter.slug),
                    status: :moved_permanently) and return
      end

      redirect_to(root_with_district_path(district: District.first)) and return
    end

    @title = "Übersicht zur Bezirkspolitik in #{@district.name}: Bezirksversammlung, Gremien, Drucksachen und Termine"

    @quarters = Quarter.in_district(@district.number).by_name
    @documents = @district.documents.complete.latest_first.limit(10)
    @meetings = @district.meetings.complete.recent.latest_first.limit(10)
  end
end
