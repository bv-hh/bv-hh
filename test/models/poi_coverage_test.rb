# frozen_string_literal: true

require 'test_helper'

class PoiCoverageTest < ActiveSupport::TestCase
  setup do
    TransitGazetteer.reset!
    Document.delete_all
    @district = districts(:hamburg_nord)
  end

  teardown { TransitGazetteer.reset! }

  test 'classifies each extracted name by the step that would resolve it' do
    document(%w[Testallee Teststadtpark Spielplatz Barmbek-Nord Hamburg Erfindungsweg])

    counts = PoiCoverage.new.run.counts

    assert_equal 1, counts[:street][:instances]
    assert_equal 1, counts[:poi][:instances]
    assert_equal 1, counts[:poi_generic][:instances]
    assert_equal 1, counts[:quarter][:instances]
    assert_equal 1, counts[:blocked][:instances]
    assert_equal 1, counts[:unresolved][:instances]
  end

  test 'counts a spelling variant as the street register hit it is' do
    document(['Heilwigstrasse'])

    assert_equal 1, PoiCoverage.new.run.counts[:street][:instances]
  end

  test 'classifies an OCR-damaged street by the trigram match that resolves it' do
    document(['Testalee'])

    assert_equal 1, PoiCoverage.new.run.counts[:fuzzy][:instances]
  end

  test 'reports what the POI gazetteer takes off Google' do
    document(%w[Teststadtpark Erfindungsweg])

    report = PoiCoverage.new.run

    assert_equal 2, report.google
    assert_equal 1, report.answered
    assert_equal 1, report.unresolved
    assert_equal '50.0%', report.google_share(report.answered)
  end

  test 'a POI is resolved only for the district it sits in' do
    wandsbek = District.create!(name: 'Wandsbek', allris_base_url: 'https://example.test')
    document(['Teststadtpark'], district: wandsbek)
    # pois(:teststadtpark_wandsbek) carries the same name in Bezirk 5.
    assert_equal 1, PoiCoverage.new.run.counts[:poi][:instances]

    Document.delete_all
    eimsbuettel = District.create!(name: 'Eimsbüttel', allris_base_url: 'https://example.test')
    document(['Teststadtpark'], district: eimsbuettel)

    assert_equal 1, PoiCoverage.new.run.counts[:unresolved][:instances]
  end

  test 'counts distinct names separately from instances' do
    document(%w[Teststadtpark Teststadtpark])

    data = PoiCoverage.new.run.counts[:poi]

    assert_equal 2, data[:instances]
    assert_equal 1, data[:names].size
  end

  test 'finds station references in the text, which the extracted names miss' do
    document([], title: 'Umbau der Haltestelle U/S Barmbek')

    found, sampled, stations = PoiCoverage.new.transit_sample

    assert_equal 1, found
    assert_equal 1, sampled
    assert_equal ['Barmbek'], stations
  end

  test 'counts existing Google locations and which of them the registers reproduce' do
    report = PoiCoverage.new
    google = report.google_locations

    assert(google.none? { |location| location.place_id.to_s.start_with?('gazetteer:', 'osm:') })
  end

  private

  def document(names, district: @district, title: 'Testdrucksache')
    @allris_id = @allris_id.to_i + 1
    Document.create!(district: district, title: title, extracted_locations: names, allris_id: @allris_id)
  end
end
