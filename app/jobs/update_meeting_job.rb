class UpdateMeetingJob < ApplicationJob
  def perform(meeting)
    meeting.agenda_items.delete_all
    meeting.retrieve_from_allris
    meeting.save!
  end
end
