# frozen_string_literal: true

class RetrieveAttachmentsJob < ApplicationJob
  queue_as :attachments

  # Something that has WithAttachments included
  def perform(entity)
    entity.retrieve_attachments!
  end
end
