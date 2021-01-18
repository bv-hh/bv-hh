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
    district.documents.where('created_at > ?', 1.month.ago).find_each(&:update_later!)
    district.meetings.where('date >= ?', Date.today).find_each(&:update_later!)
  end
end
