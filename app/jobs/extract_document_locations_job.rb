# frozen_string_literal: true

class ExtractDocumentLocationsJob < ApplicationJob

  LIMIT = 5000

  queue_as :documents

  def perform
    Document.locations_not_extracted.limit(LIMIT).find_each do |document|
      document.extract_locations!
    end
  end

end
