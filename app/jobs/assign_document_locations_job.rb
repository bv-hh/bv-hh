# frozen_string_literal: true

class AssignDocumentLocationsJob < ApplicationJob
  queue_as :documents

  def perform(document)
    document.assign_locations!
  end
end
