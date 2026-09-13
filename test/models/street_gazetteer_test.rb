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

  test 'a variant never shadows a street that really carries that spelling' do
    # Whatever the variants generate, every register name still matches itself.
    Street.distinct.pluck(:normalized_name).first(50).each do |name|
      next if name.length < StreetGazetteer::MIN_LENGTH

      assert_includes StreetGazetteer.match(name), name
    end
  end
end
