# frozen_string_literal: true

class Committee < ApplicationRecord
  belongs_to :district
  has_many :meetings, dependent: :nullify

  scope :open, -> { where(public: true) }
end
