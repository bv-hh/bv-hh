# frozen_string_literal: true

# == Schema Information
#
# Table name: committees
#
#  id               :bigint           not null, primary key
#  average_duration :integer
#  inactive         :boolean          default(FALSE)
#  name             :string
#  order            :integer          default(0)
#  public           :boolean          default(TRUE)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  allris_id        :integer
#  district_id      :bigint
#
# Indexes
#
#  index_committees_on_allris_id    (allris_id)
#  index_committees_on_district_id  (district_id)
#
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
