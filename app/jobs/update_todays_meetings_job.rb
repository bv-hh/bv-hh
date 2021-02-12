# frozen_string_literal: true

class UpdateTodaysMeetingsJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        UpdateTodaysMeetingsJob.perform_later(d)
      end

      # Purge stale agenda items
      AgendaItem.where(meeting_id: nil).delete_all
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.meetings.where(date: Time.zone.today).find_each(&:update_later!)
  end
end
