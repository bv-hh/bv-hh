# frozen_string_literal: true

require 'test_helper'

class FeedsHelperTest < ActionView::TestCase
  setup { Quarter.reset! }
  teardown { Quarter.reset! }

  test 'feed_title names places, district and topics' do
    district = districts(:hamburg_nord)

    assert_equal 'BV-HH — Drucksachen · Radverkehr', feed_title(FeedQuery.new(topics: ['radverkehr']))
    assert_equal 'BV-HH — Drucksachen aus Hamburg-Nord · Radverkehr',
                 feed_title(FeedQuery.new(district:, topics: ['radverkehr']))
    assert_equal 'BV-HH — Drucksachen zu Barmbek-Nord (Hamburg-Nord)',
                 feed_title(FeedQuery.new(district:, quarters: ['Barmbek-Nord']))
  end

  test 'feed_link_params gives topics as slugs' do
    assert_equal({ topics: ['kinder-jugend'] }, feed_link_params(FeedQuery.new(topics: ['kinder_jugend'])))
  end
end
