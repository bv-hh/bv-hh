# frozen_string_literal: true

class MeetingsController < ApplicationController
  def index
    @meetings = @district.meetings.complete.latest_first.includes(:agenda_items)

    page = params[:page]
    future_meetings = @meetings.in_future.count
    if page.blank? && future_meetings.positive?
      page = (future_meetings / Meeting.default_per_page).floor + 1
      redirect_to meetings_path(page: page) and return
    end

    @meetings = @meetings.page(page)
    @title = "Sitzungstermine/Sitzungskalender der Bezirksversammlung #{@district.name} und ihrer Gremien"
  end

  def show
    @meeting = Meeting.complete.find(params[:id]&.split('-')&.last)
    @agenda_items = @meeting.agenda_items.sort_by { |i| i.number.gsub(/[^0-9,^.]/, '').split('.').map(&:to_i) }

    respond_to do |format|
      format.html do
        full_meeting_path = meeting_path(@meeting, district: @meeting.district)
        redirect_to(full_meeting_path, status: :moved_permanently) and return unless request.path == full_meeting_path

        set_meta(@meeting)
      end
      format.xlsx do
        response.headers['Content-Disposition'] = "attachment; filename=\"#{I18n.l(@meeting.date)} - #{@meeting.title}.xlsx\""
      end
    end
  end

  def allris
    redirect_to root_path and return if @district.blank?

    @meeting = @district.meetings.find_by!(allris_id: params[:allris_id])
    redirect_to(meeting_path(@meeting, district: @meeting.district))
  end

  def minutes
    @meeting = Meeting.complete.find(params[:id]&.split('-')&.last)

    full_meeting_minutes_path = minutes_meeting_path(@meeting, district: @meeting.district)
    redirect_to(full_meeting_minutes_path, status: :moved_permanently) and return unless request.path == full_meeting_minutes_path

    @agenda_items = @meeting.agenda_items.sort_by { |i| i.number.gsub(/[^0-9,^.]/, '').split('.').map(&:to_i) }
    @title = "Protokoll #{@meeting.title} vom #{I18n.l @meeting.date}"
  end

  private

  def set_meta(meeting)
    committee_title = meeting.committee&.name || meeting.title
    @title = "#{I18n.l(meeting.date)} - #{committee_title} - #{meeting.district.name}"
    @meta_description = "#{I18n.l(meeting.start_time, default: '--:--')} Uhr, #{meeting.room}, #{meeting.location} #{helpers.strip_tags(meeting.title).squish.truncate(120)}"
  end
end
