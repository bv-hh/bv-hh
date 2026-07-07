# == Schema Information
#
# Table name: locations
#
#  id                :integer          not null, primary key
#  name              :string
#  place_id          :string
#  latitude          :float
#  longitude         :float
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  normalized_name   :string
#  extracted_name    :string
#  district_id       :integer
#  formatted_address :string
#
# Indexes
#
#  index_locations_on_district_id      (district_id)
#  index_locations_on_name             (name)
#  index_locations_on_normalized_name  (normalized_name)
#  index_locations_on_place_id         (place_id)
#

# frozen_string_literal: true

require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  setup { @district = districts(:hamburg_nord) }

  test 'determine_locations resolves a gazetteer street from register coordinates without Google' do
    location = nil
    assert_difference -> { Location.count }, 1 do
      location = Location.determine_locations('Testallee', @district).sole
    end

    assert_equal 'Testallee', location.name
    assert_in_delta 53.58, location.latitude
    assert_in_delta 10.03, location.longitude
    assert_equal 'gazetteer:02;4;01;401;0401;T0010', location.place_id
    assert_equal @district, location.district
  end

  test 'determine_locations resolves a cross-district street whose point is outside the district bbox' do
    location = Location.determine_locations('Julius-Vosseler-Straße', @district).sole

    assert_equal 'Julius-Vosseler-Straße', location.name
    assert_equal @district, location.district
  end

  test 'determine_locations reuses an existing location on the second call' do
    Location.determine_locations('Testallee', @district)

    assert_no_difference -> { Location.count } do
      Location.determine_locations('Testallee', @district)
    end
  end

  test 'determine_locations returns nothing for a blocked name' do
    assert_empty Location.determine_locations('Hamburg', @district)
  end
end
