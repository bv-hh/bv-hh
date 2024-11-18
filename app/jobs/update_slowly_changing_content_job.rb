# frozen_string_literal: true

class UpdateSlowlyChangingContentJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        UpdateSlowlyChangingContentJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    past_meetings = district.meetings.where.not(id: district.meetings.joins(:agenda_items).where.not(agenda_items: { allris_id: nil }).distinct)
    past_meetings.where(date: ..30.days.ago).find_each(&:update_later!)

    district.agenda_items.incomplete.find_each(&:update_later!)
  end
end
