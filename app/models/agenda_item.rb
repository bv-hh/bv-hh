# frozen_string_literal: true

class AgendaItem < ApplicationRecord
  belongs_to :meeting
  belongs_to :document, optional: true

  validates :meeting, presence: true

  scope :by_number, -> { order(number: :asc) }
  scope :by_meeting, -> { joins(:meeting).includes(:meeting).merge(Meeting.latest_first) }
end
