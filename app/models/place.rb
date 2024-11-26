# frozen_string_literal: true

# == Schema Information
#
# Table name: places
#
#  id         :bigint           not null, primary key
#  locations  :json
#  query      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_places_on_query  (query)
#
class Place < ApplicationRecord
  validates :query, presence: true
end
