# frozen_string_literal: true

class DistrictsController < ApplicationController
  def show
    return redirect_elsewhere if @district.nil?

    @title = "Übersicht zur Bezirkspolitik in #{@district.name}: Bezirksversammlung, Gremien, Drucksachen und Termine"

    @quarters = Quarter.in_district(@district.number).by_name
    @documents = @district.documents.complete.latest_first.limit(10)
    @meetings = @district.meetings.complete.recent.latest_first.limit(10)
    @topic_counts = cached_topic_counts(:district, @district.id) { @district.documents.complete }
  end

  private

  def redirect_elsewhere
    # /langenhorn is a Quarter, not a district: the route above matches the
    # single-segment form first, so send it on to its canonical two-segment
    # URL rather than dumping the visitor on an arbitrary district.
    quarter = Quarter.lookup(params[:district])
    if quarter.present? && quarter.district.present?
      redirect_to(quarter_path(district: quarter.district, quarter: quarter.slug), status: :moved_permanently)
    else
      redirect_to(root_with_district_path(district: District.first))
    end
  end
end
