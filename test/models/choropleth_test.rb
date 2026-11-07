# frozen_string_literal: true

require 'test_helper'

class ChoroplethTest < ActiveSupport::TestCase
  setup { Quarter.reset! }
  teardown { Quarter.reset! }

  test 'an area without enough residents has no rate' do
    quarter = quarters(:ohlsdorf)

    assert_nil ChoroplethArea.new(shapes: [quarter], count: 5, residents: 1_999).rate
    assert_nil ChoroplethArea.new(shapes: [quarter], count: 5, residents: nil).rate
    assert_in_delta 25.0, ChoroplethArea.new(shapes: [quarter], count: 5, residents: 2_000).rate
  end

  test 'names two Stadtteile counted together' do
    area = ChoroplethArea.new(shapes: quarters(:barmbek_nord, :ohlsdorf), count: 1, residents: 5_000)

    assert_equal 'Barmbek-Nord und Ohlsdorf', area.name
    assert_predicate area, :combined?
  end

  test 'splits the rates into five shades, rounded to tens' do
    choropleth = Choropleth.new([40, 60, 80, 100, 120, 140, 160, 180, 200, 220].map { |count| area(count) })

    assert_equal [80, 120, 160, 200], choropleth.breaks
    assert_equal ['unter 80', '80–119', '120–159', '160–199', 'ab 200'], choropleth.shades.map(&:label)
    assert_equal Choropleth::RAMP, choropleth.shades.map(&:color)
  end

  test 'spreads fewer shades over the whole ramp' do
    choropleth = Choropleth.new([area(100), area(100), area(300)])

    assert_equal [Choropleth::RAMP.first, Choropleth::RAMP.last], choropleth.shades.map(&:color)
  end

  test 'shows an area without a rate in grey, after the others' do
    without = ChoroplethArea.new(shapes: [quarters(:ohlsdorf)], count: 50, residents: nil)
    choropleth = Choropleth.new([without, area(100), area(200)])

    assert_equal Choropleth::NO_RATE, choropleth.color(without)
    assert_predicate choropleth, :no_rate?
    assert_equal without, choropleth.ranked.last
  end

  test 'one feature per Stadtteil, with its shape and a label point inside it' do
    choropleth = Choropleth.new([area(100)])
    feature = choropleth.features(->(quarter) { "/#{quarter.slug}" }).first
    lng, lat, radius = feature[:label]

    assert_equal '/barmbek-nord', feature[:path]
    assert_equal 1_000, feature[:count]
    assert_equal quarters(:barmbek_nord).geometry, feature[:polygons]
    assert quarters(:barmbek_nord).contains?(lat, lng)
    assert_operator radius, :>, 0
  end

  private

  # An area with +rate+ Drucksachen per 10,000 residents.
  def area(rate)
    ChoroplethArea.new(shapes: [quarters(:barmbek_nord)], count: rate * 10, residents: 100_000)
  end
end
