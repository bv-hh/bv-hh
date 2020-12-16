# frozen_string_literal: true

class MeetingsController < ApplicationController
  def index
    @meetings = @district.meetings.latest_first.page(params[:page])
  end

  def show
    @meeting = @district.meetings.find(params[:id])
  end
end
