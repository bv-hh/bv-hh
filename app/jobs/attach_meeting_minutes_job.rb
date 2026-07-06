# frozen_string_literal: true

class AttachMeetingMinutesJob < ApplicationJob
  queue_as :meetings

  def perform(meeting)
    meeting.retrieve_minutes_from_allris!
  end
end
