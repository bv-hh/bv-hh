# frozen_string_literal: true

class DistrictsController < ApplicationController
  DOCUMENTS = 8
  MEETINGS = 4
  TOP_TOPICS = 6

  def show
    return redirect_elsewhere if @district.nil?

    @title = "Übersicht zur Bezirkspolitik in #{@district.name}: Bezirksversammlung, Gremien, Drucksachen und Termine"
    @hero_search = true

    @quarters = Quarter.in_district(@district.number).by_name
    @documents = @district.documents.complete.latest_first.limit(DOCUMENTS)
    @document_count = @district.documents.complete.count
    @meeting_count = @district.meetings.complete.count

    load_upcoming_meetings

    @topic_counts = cached_topic_counts(:district, @district.id) { @district.documents.complete }
  end

  private

  # The next plenary session, and the next public meetings apart from it.
  def load_upcoming_meetings
    upcoming = @district.meetings.complete.in_future.order(:date, :start_time)
    @next_assembly = upcoming.of_assembly.first
    @next_meetings = upcoming.open_to_public.where.not(id: @next_assembly).limit(MEETINGS)
  end

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
