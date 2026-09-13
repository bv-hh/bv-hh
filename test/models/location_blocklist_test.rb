# frozen_string_literal: true

require 'test_helper'

class LocationBlocklistTest < ActiveSupport::TestCase
  setup do
    BlockedLocationName.reset!
    Quarter.reset!
    # Three districts, so breadth is observable at all.
    @districts = [districts(:hamburg_nord),
                  District.create!(name: 'Altona', order: 1, allris_base_url: 'https://example.test'),
                  District.create!(name: 'Harburg', order: 6, allris_base_url: 'https://example.test')]
  end

  teardown do
    BlockedLocationName.reset!
    Quarter.reset!
  end

  def document_mentioning(names, district:, number: rand(100_000))
    Document.create!(district: district, allris_id: rand(1_000_000), number: "x-#{number}",
                     title: 'Test', extracted_locations: names)
  end

  def spread(name, districts = @districts)
    districts.each { |district| document_mentioning([name], district: district) }
  end

  test 'flags a name appearing across several districts' do
    spread('BUKEA')

    assert_includes LocationBlocklist.new.candidates.map(&:name), 'BUKEA'
  end

  test 'ignores a name confined to one district' do
    3.times { document_mentioning(['Klingelhof'], district: @districts.first) }

    assert_not_includes LocationBlocklist.new.candidates.map(&:name), 'Klingelhof'
  end

  test 'ignores a name that is too rare even if spread out' do
    spread('Selten', @districts.first(2))

    assert_not_includes LocationBlocklist.new.candidates.map(&:name), 'Selten'
  end

  test 'never flags a street the register knows' do
    spread('Heilwigstraße')

    assert_predicate Street.where(normalized_name: 'heilwigstraße'), :any?, 'precondition'
    assert_not_includes LocationBlocklist.new.candidates.map(&:name), 'Heilwigstraße'
  end

  test 'never flags a Stadtteil the register knows' do
    spread('Barmbek-Nord')

    assert_not_includes LocationBlocklist.new.candidates.map(&:name), 'Barmbek-Nord'
  end

  test 'never flags something already blocked by the constant' do
    spread('Hamburg')

    assert_not_includes LocationBlocklist.new.candidates.map(&:name), 'Hamburg'
  end

  test 'apply! writes the candidates and makes them blocked' do
    spread('BUKEA')

    assert_equal 1, LocationBlocklist.new.apply!
    assert Location.blocked?('BUKEA')
    assert_equal 'computed', BlockedLocationName.find_by(normalized_name: 'bukea').source
  end

  test 'apply! records how the name qualified' do
    spread('BUKEA')
    LocationBlocklist.new.apply!
    row = BlockedLocationName.find_by(normalized_name: 'bukea')

    assert_equal 3, row.district_count
    assert_equal 3, row.occurrences
  end

  test 'apply! drops computed entries that no longer qualify' do
    BlockedLocationName.create!(name: 'Veraltet', source: 'computed')

    LocationBlocklist.new.apply!

    assert_nil BlockedLocationName.find_by(normalized_name: 'veraltet')
  end

  test 'apply! never touches a manual entry' do
    BlockedLocationName.create!(name: 'Von Hand', source: 'manual')

    LocationBlocklist.new.apply!

    assert_predicate BlockedLocationName.find_by(normalized_name: 'von hand'), :present?
  end

  test 'thresholds are adjustable' do
    spread('Knapp', @districts.first(2))

    assert_includes LocationBlocklist.new(min_districts: 2, min_occurrences: 2).candidates.map(&:name), 'Knapp'
  end
end
