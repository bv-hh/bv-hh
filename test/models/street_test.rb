# frozen_string_literal: true

# == Schema Information
#
# Table name: streets
#
#  id              :integer          not null, primary key
#  name            :string           not null
#  normalized_name :string           not null
#  latitude        :float
#  longitude       :float
#  quarter       :string
#  quarters      :string           default([]), not null, is an Array
#  quarter_keys       :string           default([]), not null, is an Array
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

  test 'in_quarter finds a street by any Quarter it crosses' do
    street = streets(:julius_vosseler)
    assert_includes Street.in_quarter('Lokstedt').to_a, street
    assert_includes Street.in_quarter('Groß Borstel').to_a, street
  end

  test 'in_quarter excludes streets that do not touch the Quarter' do
    assert_empty Street.in_quarter('Duvenstedt').to_a - [streets(:weitweg)]
    assert_not_includes Street.in_quarter('Duvenstedt').to_a, streets(:testallee)
  end

  test 'in_quarter_key finds a street by any official Ortsteil key it crosses' do
    street = streets(:julius_vosseler)
    assert_includes Street.in_quarter_key('0305').to_a, street
    assert_includes Street.in_quarter_key('0406').to_a, street
  end

  test 'crosses_quarters? is true only for multi-Quarter streets' do
    assert_predicate streets(:julius_vosseler), :crosses_quarters?
    assert_not_predicate streets(:testallee), :crosses_quarters?
  end

  test 'formatted_address composes name, postal code and quarter' do
    assert_equal 'Testallee, 22305 Barmbek-Nord', streets(:testallee).formatted_address
  end

  test 'formatted_address degrades gracefully when locality parts are missing' do
    street = streets(:testallee)
    street.postal_code = nil
    assert_equal 'Testallee, Barmbek-Nord', street.formatted_address

    street.quarter = nil
    assert_equal 'Testallee', street.formatted_address
  end
  test 'for resolves a spelling variant to the register name' do
    StreetGazetteer.reset!
    assert_equal [streets(:heilwigstrasse)], Street.for('Heilwigstrasse', districts(:hamburg_nord)).to_a
    assert_equal [streets(:heilwigstrasse)], Street.for('Heilwigstr.', districts(:hamburg_nord)).to_a
  ensure
    StreetGazetteer.reset!
  end

  test 'canonical_name falls back to the plain normalization for an unknown name' do
    assert_equal 'kein solcher weg', Street.canonical_name('Kein solcher Weg')
  end

  # A spelling variant is not a fuzzy case: "heilwigstrasse" scores only 0.61
  # against the register spelling, well under the floor. Street.for resolves
  # those exactly, and fuzzy_for is left with genuine OCR damage.
  test 'fuzzy_for corrects OCR damage within the district' do
    assert_equal [streets(:julius_vosseler)], Street.fuzzy_for('Julius-Vossler-Straße', districts(:hamburg_nord)).to_a
    assert_equal [streets(:testallee)], Street.fuzzy_for('Testalee', districts(:hamburg_nord)).to_a
  end

  test 'fuzzy_for leaves spelling variants to the exact path' do
    assert_empty Street.fuzzy_for('Heilwigstrasse', districts(:hamburg_nord))
  end

  test 'fuzzy_for refuses names too short to be distinctive' do
    assert_empty Street.fuzzy_for('Weitwg', districts(:hamburg_nord))
  end

  test 'fuzzy_for never answers with a street of another district' do
    assert_empty Street.fuzzy_for('Weitwegs', districts(:hamburg_nord)),
                 'streets(:weitweg) is in Wandsbek and must stay unreachable from Hamburg-Nord'
  end

  # Two candidates the same distance away are not a near miss, they are a
  # coin flip. Refusing is the whole reason this can be trusted where Google
  # could not.
  test 'fuzzy_for refuses to choose between two equally close names' do
    %w[Testhausstraße Testmausstraße].each do |name|
      Street.create!(name: name, latitude: 53.58, longitude: 10.0, district_numbers: [4])
    end
    StreetGazetteer.reset!

    assert_empty Street.fuzzy_for('Testkausstraße', districts(:hamburg_nord))
  ensure
    StreetGazetteer.reset!
  end

  test 'fuzzy_for finds nothing for a name that resembles nothing' do
    assert_empty Street.fuzzy_for('Sommermonaten', districts(:hamburg_nord))
  end

  test 'fuzzy_for takes a floor, so the threshold can be measured' do
    assert_empty Street.fuzzy_for('Testalee', districts(:hamburg_nord), floor: 0.99)
    assert_equal [streets(:testallee)], Street.fuzzy_for('Testalee', districts(:hamburg_nord), floor: 0.5).to_a
  end
end
