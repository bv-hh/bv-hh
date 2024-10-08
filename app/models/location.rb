# frozen_string_literal: true

# == Schema Information
#
# Table name: locations
#
#  id         :bigint           not null, primary key
#  latitude   :float
#  longitude  :float
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  place_id   :string
#
# Indexes
#
#  index_locations_on_name      (name)
#  index_locations_on_place_id  (place_id)
#
class Location < ApplicationRecord

  BLOCKED_LOCATIONS = %w(norderstedt) + District.all.map(&:name).map(&:downcase)

  validates :name, presence: true

  def self.blocked?(location)
    BLOCKED_LOCATIONS.include?(location.downcase)
  end
end
