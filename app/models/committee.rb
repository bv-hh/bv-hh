# frozen_string_literal: true

class Committee < ApplicationRecord
  belongs_to :district
  has_many :meetings, dependent: :nullify

  scope :open, -> { where(public: true) }
  scope :active, -> { where(inactive: false) }

  def update_average_duration!
    total_duration = 0
    meetings.with_duration.find_each do |meeting|
      total_duration += meeting.duration
    end

    self.average_duration = (total_duration.to_f / meetings.with_duration.count).round

    save!
  end
end
