# frozen_string_literal: true

class CheckForDocumentUpdatesJob < ApplicationJob
  def perform(district = nil)
    if district.nil?
      District.find_each do |d|
        CheckForDocumentUpdatesJob.perform_later(d)
      end
    else
      perform_for(district)
    end
  end

  def perform_for(district)
    district.check_for_document_updates
  end
end
