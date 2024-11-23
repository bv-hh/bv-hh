# frozen_string_literal: true

class ExtractDocumentLocationsJob < ApplicationJob

  queue_as :documents

  def perform(document)
    document.extract_locations!
  end

end
