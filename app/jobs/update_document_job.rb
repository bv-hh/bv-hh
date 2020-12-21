# frozen_string_literal: true

class UpdateDocumentJob < ApplicationJob
  queue_as :documents

  def perform(document)
    document.retrieve_from_allris
    document.save!
  end
end
