# frozen_string_literal: true

class MeetingsController < ApplicationController
  def index
    @meetings = @district.meetings.complete.latest_first.page(params[:page])
  end

  def show
    @meeting = @district.meetings.complete.find(params[:id])
    @agenda_items = @meeting.agenda_items.sort_by { |i| i.number.gsub(/[^0-9,^.]/, '').split('.').map(&:to_i) }
    @title = "#{I18n.l(@meeting.date)} - Sitzung #{@meeting.committee.name} - #{@meeting.district.name}"
    @meta_description = "#{I18n.l(@meeting.start_time)} Uhr, #{@meeting.room}, #{@meeting.location} #{helpers.strip_tags(@meeting.title).squish.truncate(120)}"
  end
end
