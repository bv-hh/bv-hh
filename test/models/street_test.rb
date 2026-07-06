# == Schema Information
#
# Table name: streets
#
#  id              :integer          not null, primary key
#  name            :string           not null
#  normalized_name :string           not null
#  latitude        :float
#  longitude       :float
#  stadtteil       :string
#  postal_code     :string
#  street_key      :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_streets_on_normalized_name  (normalized_name)
#  index_streets_on_street_key       (street_key)
#

# frozen_string_literal: true

require 'test_helper'

class StreetTest < ActiveSupport::TestCase
  setup { @district = districts(:hamburg_nord) }

  test 'normalize lowercases and collapses punctuation to single spaces' do
    assert_equal 'julius vosseler straße', Street.normalize('Julius-Vosseler-Straße')
    assert_equal 'am alten markt', Street.normalize('  Am   Alten Markt ')
  end

  test 'for returns a street that belongs to the district Bezirk' do
    assert_equal [streets(:testallee)], Street.for('Testallee', @district).to_a
  end

  test 'for matches regardless of input casing and punctuation' do
    assert_equal [streets(:julius_vosseler)], Street.for('julius vosseler straße', @district).to_a
  end

  test 'for matches a cross-district street even when its point is outside the district bbox' do
    street = streets(:julius_vosseler)
    assert Location.out_of_bounds?(street.latitude, street.longitude, @district.bounds),
           'fixture precondition: representative point is outside Hamburg-Nord bounds'
    assert_includes Street.for('Julius-Vosseler-Straße', @district).to_a, street
  end

  test 'for excludes streets belonging to another district' do
    assert_empty Street.for('Weitweg', @district).to_a
  end

  test 'for returns nothing for a district without a known Bezirk number' do
    @district.name = 'Umland'
    assert_empty Street.for('Testallee', @district).to_a
  end
end
