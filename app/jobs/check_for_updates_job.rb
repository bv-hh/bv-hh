# frozen_string_literal: true

class CheckForUpdatesJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        CheckForUpdatesJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.check_for_document_updates
    district.check_for_meeting_updates

    district.update_documents
    district.update_meetings
  end
end
