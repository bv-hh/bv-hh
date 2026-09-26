# frozen_string_literal: true

require 'test_helper'

class StreetGazetteerTest < ActiveSupport::TestCase
  setup { StreetGazetteer.reset! }
  teardown { StreetGazetteer.reset! }

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
