# frozen_string_literal: true

class ExtractDocumentLocationsJob < ApplicationJob
  LIMIT = 5000

  queue_as :documents

  def perform(document = nil)
    if document.nil?
      Document.latest_first.locations_not_extracted.limit(LIMIT).find_each do |document|
        ExtractDocumentLocationsJob.perform_later(document)
      end
    else
      document.extract_locations!
    end
  end
end
