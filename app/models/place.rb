# frozen_string_literal: true

# == Schema Information
#
# Table name: places
#
#  id          :bigint           not null, primary key
#  locations   :json
#  query       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  district_id :bigint           not null
#
# Indexes
#
#  index_places_on_district_id  (district_id)
#  index_places_on_query        (query)
#
# Foreign Keys
#
#  fk_rails_...  (district_id => districts.id)
#
class Place < ApplicationRecord
  belongs_to :district

  validates :query, presence: true
end
