# frozen_string_literal: true

class Attachment < ApplicationRecord
  belongs_to :district
  belongs_to :document

  has_one_attached :file

  scope :by_name, -> { order(:name) }
end
