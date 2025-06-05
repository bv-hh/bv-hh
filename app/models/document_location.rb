# frozen_string_literal: true
# == Schema Information
#
# Table name: document_locations
#
#  id          :integer          not null, primary key
#  document_id :integer
#  location_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_document_locations_on_document_id  (document_id)
#  index_document_locations_on_location_id  (location_id)
#

class DocumentLocation < ApplicationRecord
  belongs_to :document
  belongs_to :location
end
