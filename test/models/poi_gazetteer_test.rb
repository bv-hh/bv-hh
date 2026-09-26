# frozen_string_literal: true

require 'test_helper'

class PoiGazetteerTest < ActiveSupport::TestCase
  setup { PoiGazetteer.reset! }
  teardown { PoiGazetteer.reset! }

  test 'finds a pinnable POI in running text' do
    assert_equal ['teststadtpark'], PoiGazetteer.match('Der Teststadtpark bekommt neue Bänke.')
  end

  test 'finds a POI by its alias' do
    assert_equal ['testpark'], PoiGazetteer.match('Pflege im Testpark')
  end

  test 'ignores categories named after titles and people' do
    Poi.create!(name: 'Zwei', category: 'tourism=artwork', osm_type: 'node', osm_id: 2001,
                latitude: 53.58, longitude: 10.0, district_number: 4)

    assert_empty PoiGazetteer.match('Die zwei Anträge')
  end

  test 'ignores a single-word name the documents of several districts use' do
    Poi.create!(name: 'Feuerwehr', category: 'leisure=playground', osm_type: 'node', osm_id: 2002,
                latitude: 53.58, longitude: 10.0, district_number: 4)
    3.times do |i|
      district = District.create!(name: "Bezirk #{i}", allris_base_url: 'https://example.test')
      Document.create!(district: district, title: 'Einsatz', full_text: 'Die Feuerwehr', allris_id: 9000 + i)
    end

    assert_empty PoiGazetteer.match('Die Feuerwehr rückt aus')
  end

  test 'keeps a name several districts use when most mentions are from its own' do
    Poi.create!(name: 'Heimatviertel', category: 'place=neighbourhood', osm_type: 'node', osm_id: 2003,
                latitude: 53.58, longitude: 10.0, district_number: 4)
    2.times do |i|
      district = District.create!(name: "Bezirk #{i}", allris_base_url: 'https://example.test')
      Document.create!(district: district, title: 'Nachbarn', full_text: 'Das Heimatviertel', allris_id: 9100 + i)
    end
    3.times do |i|
      Document.create!(district: districts(:hamburg_nord), title: 'Vor Ort', full_text: 'Im Heimatviertel',
                       allris_id: 9200 + i)
    end

    assert_equal ['heimatviertel'], PoiGazetteer.match('Das Heimatviertel wächst')
  end

  test 'ignores generic names and stations' do
    assert_empty PoiGazetteer.match('Der Spielplatz am Bahnhof Barmbek')
  end
end
