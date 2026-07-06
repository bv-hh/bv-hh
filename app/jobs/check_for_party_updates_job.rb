# frozen_string_literal: true

class CheckForPartyUpdatesJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        CheckForPartyUpdatesJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.check_for_party_updates
  end
end
