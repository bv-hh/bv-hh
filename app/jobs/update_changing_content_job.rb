# frozen_string_literal: true

class UpdateChangingContentJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        UpdateChangingContentJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.documents.where('created_at > ?', 1.week.ago).find_each(&:update_later!)
    district.meetings.where('date >= ?', Time.zone.today).find_each(&:update_later!)

    past_meetings = district.meetings.where.not(id: district.meetings.joins(:agenda_items).where.not(agenda_items: { allris_id: nil }).distinct)
    past_meetings.where('date <= ?', 30.days.ago).find_each(&:update_later!)
  end
end
