# frozen_string_literal: true

class AttachmentExtractJob < ApplicationJob
  queue_as :attachments

  def perform(attachment)
    attachment.extract_text!
  end
end
