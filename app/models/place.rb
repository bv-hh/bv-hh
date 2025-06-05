# frozen_string_literal: true

# == Schema Information
#
# Table name: places
#
#  id          :integer          not null, primary key
#  query       :string           not null
#  locations   :json
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  district_id :integer          not null
#
# Indexes
#
#  index_places_on_district_id  (district_id)
#  index_places_on_query        (query)
#

class Place < ApplicationRecord
  belongs_to :district

  validates :query, presence: true
end
