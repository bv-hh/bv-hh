# frozen_string_literal: true

require 'test_helper'

class TransitGazetteerTest < ActiveSupport::TestCase
  setup { TransitGazetteer.reset! }
  teardown { TransitGazetteer.reset! }

  test 'matches a station behind a U/S prefix' do
    assert_equal ['Barmbek'], TransitGazetteer.match('Sanierung der Haltestelle U/S Barmbek')
  end

  test 'matches the single-letter prefixes and the spelled-out ones' do
    ['S Barmbek', 'U Barmbek', 'Bahnhof Barmbek', 'Haltestelle Barmbek', 'AKN Barmbek'].each do |text|
      assert_equal ['Barmbek'], TransitGazetteer.match(text), text
    end
  end

  test 'ignores a station name without a transit prefix' do
    assert_empty TransitGazetteer.match('Spielplätze in Barmbek')
  end

  test 'takes the longest station name at the position' do
    assert_equal ['Hamburg Dammtor'], TransitGazetteer.match('Umbau S Hamburg Dammtor')
  end

  test 'returns the register spelling, distinct and in order' do
    assert_equal ['Barmbek'], TransitGazetteer.match('U Barmbek und S Barmbek')
  end

  test 'ignores a prefix followed by anything else' do
    assert_empty TransitGazetteer.match('S Bahnhofstraße und U Testallee')
  end

  test 'is empty without a text' do
    assert_empty TransitGazetteer.match(nil)
    assert_empty TransitGazetteer.match('')
  end
end
