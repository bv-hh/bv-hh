# frozen_string_literal: true

require 'test_helper'

class SearchMatchesTest < ActiveSupport::TestCase
  setup { Quarter.reset! }
  teardown { Quarter.reset! }

  test 'finds the Stadtteil the term names, however it is spelled' do
    assert_equal 'Barmbek-Nord', SearchMatches.new('Barmbek-Nord').quarter.name
    assert_equal 'Barmbek-Nord', SearchMatches.new('barmbek nord').quarter.name
  end

  test 'finds the street the term names, with the Stadtteile it runs through' do
    street = SearchMatches.new('heilwigstraße').street

    assert_equal 'Heilwigstraße', street.name
    assert_equal ['Barmbek-Nord'], street.quarters.map(&:name)
  end

  test 'finds a topic by its slug or by a part of its label' do
    assert_equal 'radverkehr', SearchMatches.new('Radverkehr').topic.key
    assert_equal 'gruen', SearchMatches.new('Bäume').topic.key
    assert_equal 'spielplaetze', SearchMatches.new('spielplätze').topic.key
  end

  test 'matches only the whole term' do
    matches = SearchMatches.new('Radverkehr Barmbek-Nord')

    assert_not matches.any?
  end

  test 'matches nothing for a blank term' do
    assert_not SearchMatches.new(' ').any?
  end
end
