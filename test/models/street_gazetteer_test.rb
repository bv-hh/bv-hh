# frozen_string_literal: true

require 'test_helper'

class StreetGazetteerTest < ActiveSupport::TestCase
  setup { StreetGazetteer.reset! }
  teardown { StreetGazetteer.reset! }

  test 'remove takes street names out of a text' do
    assert_equal 'querung der und zurück', StreetGazetteer.remove('Querung der Heilwigstraße und zurück')
  end

  test 'finds a single-word street name in running text' do
    text = 'Die Sanierung der Testallee wurde beschlossen.'
    assert_equal ['testallee'], StreetGazetteer.match(text)
  end

  test 'finds a multi-word street name across word boundaries' do
    text = 'Anwohner der Julius-Vosseler-Straße baten um Tempo 30.'
    assert_includes StreetGazetteer.match(text), 'julius vosseler straße'
  end

  test 'matches case-insensitively' do
    assert_equal ['testallee'], StreetGazetteer.match('rund um die TESTALLEE')
  end

  test 'does not match substrings inside other words' do
    assert_empty StreetGazetteer.match('Die Testalleebar hat geschlossen.')
  end

  test 'returns nothing for text without known streets' do
    assert_empty StreetGazetteer.match('Ein Beschluss ohne jede Ortsangabe.')
  end

  test 'deduplicates repeated mentions' do
    text = 'Testallee hier, Testallee dort.'
    assert_equal ['testallee'], StreetGazetteer.match(text)
  end

  test 'matches the abbreviated Straße spelling and reports the register name' do
    assert_equal ['testallee'], StreetGazetteer.match('Arbeiten in der Testallee')
    assert_equal ['heilwigstraße'], StreetGazetteer.match('Arbeiten in der Heilwigstr. beginnen')
  end

  test 'matches ss where the register writes ß' do
    assert_equal ['heilwigstraße'], StreetGazetteer.match('Anwohner der Heilwigstrasse')
  end

  test 'matches the adjective glued to the street word' do
    assert_equal ['julius vosseler straße'], StreetGazetteer.match('Arbeiten in der Julius-Vosselerstraße').last(1)
  end

  test 'matches ss for ß inside the name, whatever the suffix' do
    Street.create!(name: 'Schloßstraße', normalized_name: 'schloßstraße', street_key: 'test;schloss', district_numbers: [4])
    StreetGazetteer.reset!

    assert_equal ['schloßstraße'], StreetGazetteer.match('in der Schlossstraße')
    assert_equal ['schloßstraße'], StreetGazetteer.match('in der Schlossstr.')
  end

  test 'matches ss for ß before a final e inside the name' do
    Street.create!(name: 'Große Bergstraße', normalized_name: 'große bergstraße', street_key: 'test;berg',
                   district_numbers: [2])
    StreetGazetteer.reset!

    assert_includes StreetGazetteer.match('in der Grosse Bergstrasse'), 'große bergstraße'
  end

  test 'matches a declined feminine or place-formed adjective' do
    Street.create!(name: 'Große Johannisstraße', normalized_name: 'große johannisstraße', street_key: 'test;johannis',
                   district_numbers: [1])
    Street.create!(name: 'Hannoversche Straße', normalized_name: 'hannoversche straße', street_key: 'test;hannover',
                   district_numbers: [7])
    StreetGazetteer.reset!

    assert_equal ['große johannisstraße'], StreetGazetteer.match('zwischen Großer Johannisstraße und Domstraße')
    assert_equal ['hannoversche straße'], StreetGazetteer.match('am Rand der Hannoverschen Straße')
  end

  test 'matches a one-word name written as two' do
    Street.create!(name: 'Spitalerstraße', normalized_name: 'spitalerstraße', street_key: 'test;spitaler',
                   district_numbers: [1])
    StreetGazetteer.reset!

    assert_equal ['spitalerstraße'], StreetGazetteer.match('Weihnachtsmarkt Spitaler Straße')
  end

  test 'matches a hyphenated name written as one word' do
    assert_includes StreetGazetteer.match('in der Juliusvosselerstraße'), 'julius vosseler straße'
  end

  test 'does not decline an adjective before a bare street word' do
    Street.create!(name: 'Neuer Weg', normalized_name: 'neuer weg', street_key: 'test;neuerweg', district_numbers: [6])
    StreetGazetteer.reset!

    assert_empty StreetGazetteer.match('Wir müssen einen neuen Weg finden')
    assert_equal ['neuer weg'], StreetGazetteer.match('Anwohner im Neuer Weg')
  end

  test 'matches the -bütteler spelling of a -büttler street' do
    Street.create!(name: 'Poppenbüttler Landstraße', normalized_name: 'poppenbüttler landstraße',
                   street_key: 'test;poppenbuettel', district_numbers: [5])
    StreetGazetteer.reset!

    assert_equal ['poppenbüttler landstraße'], StreetGazetteer.match('Poppenbütteler Landstraße')
  end

  test 'matches the genitive of a street' do
    assert_equal ['weitweg'], StreetGazetteer.match('Anwohner des Weitwegs')
  end

  test 'matches a leading adjective declined after a preposition' do
    Street.create!(name: 'Alter Teichweg', normalized_name: 'alter teichweg', street_key: 'test;teichweg',
                   district_numbers: [4])
    StreetGazetteer.reset!

    assert_equal ['alter teichweg'], StreetGazetteer.match('Bebauung am Alten Teichweg')
  end

  test 'a variant never shadows a street that really carries that spelling' do
    # Whatever the variants generate, every register name still matches itself.
    Street.distinct.pluck(:normalized_name).first(50).each do |name|
      next if name.length < StreetGazetteer::MIN_LENGTH

      assert_includes StreetGazetteer.match(name), name
    end
  end
end
