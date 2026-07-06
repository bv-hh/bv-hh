# frozen_string_literal: true

class CheckForMemberUpdatesJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        CheckForMemberUpdatesJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.committees.active.find_each do |committee|
      UpdateCommitteeMembersJob.perform_later(committee)
    end
  end
end
