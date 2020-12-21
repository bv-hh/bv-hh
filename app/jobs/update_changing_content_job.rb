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
    district.update_documents
    district.update_meetings
  end
end
