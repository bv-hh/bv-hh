# frozen_string_literal: true

require 'test_helper'

class CityStatisticsTest < ActiveSupport::TestCase
  test 'counts the current legislation of every district' do
    statistics = CityStatistics.new

    assert_equal DistrictStatistics.new(districts(:hamburg_nord)).document_count, statistics.document_count
  end

  test 'compares the Bezirke by all their Drucksachen per resident' do
    district = districts(:hamburg_nord)
    area = CityStatistics.new.district_areas.find { |each| each.name == district.name }

    assert_equal Document.current_legislation(district).count, area.count
    assert_equal Population::DISTRICT_RESIDENTS['Hamburg-Nord'], area.residents
    assert_equal [District.by_number(district.number)], area.shapes
  end
end
