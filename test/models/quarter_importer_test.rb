# frozen_string_literal: true

require 'test_helper'

class QuarterImporterTest < ActiveSupport::TestCase
  setup do
    @geojson = file_fixture('quarters_sample.json').read
    @rows = QuarterImporter.new.parse(@geojson)
  end

  test 'parse extracts one row per feature with register metadata' do
    assert_equal 3, @rows.size

    test_quarter = @rows.find { |row| row[:name] == 'Teststadtteil' }
    assert_equal 'teststadtteil', test_quarter[:slug]
    assert_equal '02401', test_quarter[:key]
    assert_equal '401', test_quarter[:number]
    assert_equal 4, test_quarter[:district_number]
    assert_equal 'Hamburg-Nord', test_quarter[:district_name]
  end

  test 'parse normalizes a Polygon to the MultiPolygon shape' do
    gross = @rows.find { |row| row[:name] == 'Groß Testen' }

    assert_equal 1, gross[:geometry].size, 'one polygon'
    assert_equal 2, gross[:geometry].first.size, 'exterior ring plus one hole'
  end

  test 'parse keeps holes so they can be subtracted' do
    gross = Quarter.new(@rows.find { |row| row[:name] == 'Groß Testen' })

    assert gross.contains?(53.52, 9.82), 'inside the exterior ring'
    assert_not gross.contains?(53.56, 9.87), 'inside the hole'
  end

  test 'parse closes an unclosed ring so ray casting sees every edge' do
    ostdorf = @rows.find { |row| row[:name] == 'Ostdorf' }
    ring = ostdorf[:geometry].first.first

    assert_equal ring.first, ring.last
    assert Quarter.new(ostdorf).contains?(53.65, 10.25)
  end

  test 'parse computes the bounding box from every coordinate' do
    test_quarter = @rows.find { |row| row[:name] == 'Teststadtteil' }

    assert_in_delta 10.0, test_quarter[:min_lng]
    assert_in_delta 10.1, test_quarter[:max_lng]
    assert_in_delta 53.6, test_quarter[:min_lat]
    assert_in_delta 53.7, test_quarter[:max_lat]
  end

  test 'parse slugifies names so they survive as URL segments' do
    assert_equal 'gross-testen', @rows.find { |row| row[:name] == 'Groß Testen' }[:slug]
  end

  test 'parse rejects coordinates outside Hamburg, catching a projection change' do
    utm = @geojson.sub('[10.0, 53.6]', '[566000.0, 5936000.0]')

    assert_raises(QuarterImporter::WrongProjectionError) do
      QuarterImporter.new.parse(utm)
    end
  end

  test 'parse skips features without a name' do
    nameless = JSON.parse(@geojson)
    nameless['features'].first['properties']['stadtteil_name'] = ''

    assert_equal 2, QuarterImporter.new.parse(nameless).size
  end

  test 'parse skips features without geometry' do
    geometryless = JSON.parse(@geojson)
    geometryless['features'].first['geometry'] = nil

    assert_equal 2, QuarterImporter.new.parse(geometryless).size
  end
end
