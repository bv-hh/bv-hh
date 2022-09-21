# frozen_string_literal: true

class Attachment < ApplicationRecord
  belongs_to :district
  belongs_to :attachable, polymorphic: true

  has_one_attached :file

  scope :by_name, -> { order(:name) }

  def extract_later!
    AttachmentExtractJob.perform_later(self)
  end

  def extract_text!
    extract = file.open { |tmp| SimpleTextExtract.extract(tempfile: tmp) }
    update!(content: extract)
  end
end
