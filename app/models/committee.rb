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
  LOCAL_COMMITTEE_DESIGNATION = 'Regionalausschuss'

  belongs_to :district
  has_many :meetings, dependent: :nullify

  scope :open, -> { where(public: true) }
  scope :active, -> { where(inactive: false) }
  scope :by_order, -> { order(:order) }

  def update_average_duration!
    total_duration = 0
    meetings.with_duration.find_each do |meeting|
      total_duration += meeting.duration
    end

    self.average_duration = (total_duration.to_f / meetings.with_duration.count).round

    save!
  end

  def local?
    name.include?(LOCAL_COMMITTEE_DESIGNATION)
  end

  def area
    return nil unless local?

    name.gsub(LOCAL_COMMITTEE_DESIGNATION, '')&.strip
  end

  def matches_area?(location_name)
    return false unless local?
    return false if location_name.blank?

    normalized_location_name = location_name.gsub(/[^\w ]/, '').downcase
    area&.gsub(/[^\w ]/, '')&.downcase == normalized_location_name
  end
end
