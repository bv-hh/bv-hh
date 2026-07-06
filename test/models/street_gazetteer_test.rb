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
end
