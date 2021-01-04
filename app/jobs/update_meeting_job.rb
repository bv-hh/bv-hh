# frozen_string_literal: true

class UpdateMeetingJob < ApplicationJob
  queue_as :meetings

  def perform(meeting)
    meeting.retrieve_from_allris!
  end
end
