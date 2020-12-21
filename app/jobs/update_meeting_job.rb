# frozen_string_literal: true

class UpdateMeetingJob < ApplicationJob
  queue_as :meetings

  def perform(meeting)
    meeting.agenda_items.delete_all
    meeting.retrieve_from_allris
    meeting.save!
  end
end
