# frozen_string_literal: true

class UpdateAverageDurationsJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        UpdateAverageDurationsJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.committees.active.each(&:update_average_duration!)
  end
end
