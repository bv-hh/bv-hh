class CheckForUpdatesJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |district|
        CheckForUpdatesJob.perform_later(district)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.check_for_document_updates
    district.check_for_meeting_updates
  end
end
