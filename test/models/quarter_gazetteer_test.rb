# frozen_string_literal: true

require 'test_helper'

class QuarterGazetteerTest < ActiveSupport::TestCase
  setup { QuarterGazetteer.reset! }
  teardown { QuarterGazetteer.reset! }

  test 'finds a Stadtteil and reports the register spelling' do
    assert_equal ['Ohlsdorf'], QuarterGazetteer.match('Der Friedhof in ohlsdorf wird saniert.')
  end

  test 'finds a hyphenated and a two-word Stadtteil' do
    assert_equal ['Barmbek-Nord', 'Groß Borstel'], QuarterGazetteer.match('Barmbek-Nord und Groß Borstel')
  end

  test 'finds the genitive' do
    assert_equal ['Ohlsdorf'], QuarterGazetteer.match('die Straßen Ohlsdorfs')
  end

  test 'finds ss where the register writes ß' do
    assert_equal ['Groß Borstel'], QuarterGazetteer.match('in Gross Borstel')
  end

  test 'finds each Stadtteil in a compound committee name' do
    assert_equal %w[Lokstedt Ohlsdorf], QuarterGazetteer.match('Regionalausschuss Lokstedt-Ohlsdorf')
  end

  test 'skips a Stadtteil named as its district' do
    Quarter.create!(name: 'Wandsbek', slug: 'wandsbek', key: 'test-wandsbek', geometry: [[[[10.0, 53.0], [10.1, 53.0], [10.0, 53.1]]]], district_number: 5)
    QuarterGazetteer.reset!

    assert_empty QuarterGazetteer.match('Das Bezirksamt Wandsbek teilt mit')
    assert_equal ['Wandsbek'], QuarterGazetteer.match('Der Wandsbeker Markt liegt in Wandsbek')
  end

  test 'does not match inside a longer word' do
    assert_empty QuarterGazetteer.match('Die Ohlsdorfer Straße')
  end
end
