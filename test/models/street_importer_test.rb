# frozen_string_literal: true

require 'test_helper'

class StreetImporterTest < ActiveSupport::TestCase
  setup do
    @gml = file_fixture('dog_strassen_sample.xml').read
    @rows = StreetImporter.new.parse(@gml)
  end

  test 'parse extracts one row per street with name and coordinates' do
    assert_equal 3, @rows.size

    testallee = @rows.find { |row| row[:name] == 'Testallee' }
    assert_equal 'testallee', testallee[:normalized_name]
    assert_in_delta 53.58, testallee[:latitude]
    assert_in_delta 10.03, testallee[:longitude]
    assert_equal 'Barmbek-Nord', testallee[:stadtteil]
    assert_equal '22305', testallee[:postal_code]
    assert_equal '02;4;01;401;0401;T0010', testallee[:street_key]
    assert_equal [4], testallee[:bezirke]
  end

  test 'parse collects distinct Bezirk numbers for a cross-district street' do
    julius = @rows.find { |row| row[:name] == 'Julius-Vosseler-Straße' }
    assert_equal [3, 4], julius[:bezirke]
  end

  test 'parse normalizes hyphenated names to space-separated lowercase' do
    julius = @rows.find { |row| row[:name] == 'Julius-Vosseler-Straße' }
    assert_equal 'julius vosseler straße', julius[:normalized_name]
  end

  test 'parse uses the representative position, not the street axis' do
    testallee = @rows.find { |row| row[:name] == 'Testallee' }
    assert_in_delta 53.58, testallee[:latitude]
    assert_in_delta 10.03, testallee[:longitude]
  end
end
