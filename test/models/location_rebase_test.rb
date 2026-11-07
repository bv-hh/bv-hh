# frozen_string_literal: true

require 'test_helper'

class LocationRebaseTest < ActiveSupport::TestCase
  setup do
    @location = locations(:heilwigstrasse)
    # Where Google put it: a little off the register's point.
    @location.update!(latitude: 53.5897, longitude: 10.0031, place_id: 'ChIJheilwig', formatted_address: 'Heilwigstraße, Google')
  end

  test 'moves a Google location onto its register street' do
    move = LocationRebase.new.moves.find { |entry| entry.location == @location }

    assert_equal "gazetteer:#{streets(:heilwigstrasse).street_key}", move.place_id
    assert_operator move.metres, :>, 0

    LocationRebase.new.apply!
    @location.reload

    assert_in_delta streets(:heilwigstrasse).latitude, @location.latitude
    assert_in_delta streets(:heilwigstrasse).longitude, @location.longitude
    assert_equal "gazetteer:#{streets(:heilwigstrasse).street_key}", @location.place_id
  end

  test 'keeps the location and its Drucksachen' do
    documents = @location.documents.to_a

    LocationRebase.new.apply!

    assert_equal documents, @location.reload.documents.to_a
  end

  test 'takes a named place where no street has the name' do
    poi = pois(:hamburger_testpark)
    location = Location.create!(district: districts(:hamburg_nord), name: poi.name, extracted_name: poi.name,
                                latitude: 53.6, longitude: 10.0, place_id: 'ChIJpark')

    move = LocationRebase.new.moves.find { |entry| entry.location == location }

    assert_equal poi.place_key, move.place_id
  end

  test 'leaves alone what the registers placed and what they do not know' do
    moved = LocationRebase.new.moves.map(&:location)

    assert_not_includes moved, locations(:julius_vosseler)
    # The fixture's Stadtpark has a Google id, but no register knows a Stadtpark.
    assert_not_includes moved, locations(:stadtpark)
  end
end
