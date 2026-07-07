# frozen_string_literal: true

class UpdateCommitteeAveragesJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        UpdateCommitteeAveragesJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.committees.active.each do |committee|
      committee.update_average_duration!
      committee.update_average_word_count!
    end
  end
end
