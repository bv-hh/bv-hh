# frozen_string_literal: true

require 'test_helper'

class DistrictOutlineTest < ActiveSupport::TestCase
  setup do
    Quarter.reset!
  end

  teardown do
    Quarter.reset!
  end

  test 'dissolves neighbouring Stadtteile into one ring' do
    quarter(:west, square(0, 0, 1, 1))
    quarter(:east, square(1, 0, 2, 1))

    outline = DistrictOutline.for(99)

    assert_equal 1, outline.size, 'one polygon'
    assert_equal 1, outline.first.size, 'without holes'

    ring = outline.first.first

    assert_equal ring.first, ring.last, 'the ring is closed'
    assert_equal [[0.0, 0.0], [0.0, 1.0], [1.0, 1.0], [2.0, 1.0], [2.0, 0.0], [1.0, 0.0]].sort, ring[0..-2].sort
  end

  test 'keeps a ring inside another one as a hole' do
    quarter(:ring, [[square_ring(0, 0, 4, 4), square_ring(1, 1, 3, 3)]])

    outline = DistrictOutline.for(99)

    assert_equal 1, outline.size
    assert_equal 2, outline.first.size, 'exterior plus the hole'
    assert_equal square_ring(1, 1, 3, 3).sort, outline.first.last.sort
  end

  test 'keeps separate parts as separate polygons' do
    quarter(:mainland, square(0, 0, 1, 1))
    quarter(:island, square(5, 5, 6, 6))

    assert_equal 2, DistrictOutline.for(99).size
  end

  test 'is empty for a district without imported Stadtteile' do
    assert_empty DistrictOutline.for(99)
    assert_empty DistrictOutline.for(nil)
  end

  test 'Quarter.reset! drops the memoized outline' do
    quarter(:west, square(0, 0, 1, 1))

    assert_empty DistrictOutline.for(98), 'precondition: nothing imported for this district yet'

    quarter(:other, square(0, 0, 1, 1), district_number: 98)
    Quarter.reset!

    assert_equal 1, DistrictOutline.for(98).size
  end

  private

  def quarter(name, geometry, district_number: 99)
    Quarter.create!(name: name.to_s, slug: "test-#{name}", key: "test-#{name}", district_number:, geometry:)
  end

  # A GeoJSON MultiPolygon of one square, counter-clockwise.
  def square(min_lng, min_lat, max_lng, max_lat)
    [[square_ring(min_lng, min_lat, max_lng, max_lat)]]
  end

  def square_ring(min_lng, min_lat, max_lng, max_lat)
    [[min_lng, min_lat], [max_lng, min_lat], [max_lng, max_lat], [min_lng, max_lat], [min_lng, min_lat]]
      .map { |lng, lat| [lng.to_f, lat.to_f] }
  end
end
