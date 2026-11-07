# frozen_string_literal: true

require 'test_helper'

class MapQueryTest < ActiveSupport::TestCase
  # The fixtures' meetings are on 9 and 12 October 2023.
  setup { travel_to Date.new(2023, 10, 20) }

  test 'an unknown range falls back to the first' do
    assert_equal 'aktuell', MapQuery.new(range: 'irgendwann').range
  end

  test 'recent reaches back a few months and forward to every meeting' do
    assert_includes MapQuery.new.documents, documents(:document_7)

    travel_to Date.new(2024, 6, 1)
    assert_not_includes MapQuery.new.documents, documents(:document_7)

    travel_to Date.new(2023, 9, 1)
    query = MapQuery.new

    assert_includes query.documents, documents(:document_7)
    assert_equal 1, query.places.find { |id, *| id == locations(:heilwigstrasse).id }.last, 'still to be discussed'
  end

  test 'the current legislation follows the districts\' numbers' do
    assert_includes MapQuery.new(range: 'wahlperiode').documents, documents(:document_7)
    assert_not_includes MapQuery.new(range: 'letzte-wahlperiode').documents, documents(:document_7)
  end

  test 'the last legislation is what came before the current numbers' do
    districts(:hamburg_nord).update!(first_legislation_number: '22-0001')

    assert_includes MapQuery.new(range: 'letzte-wahlperiode').documents, documents(:document_7)
  end

  test 'a topic narrows the Drucksachen' do
    documents(:document_7).update_columns(topics: ['strassenverkehr']) # rubocop:disable Rails/SkipsModelValidations
    documents(:document_227).update_columns(topics: []) # rubocop:disable Rails/SkipsModelValidations

    query = MapQuery.new(topic: Topic.find('strassenverkehr'))

    assert_includes query.documents, documents(:document_7)
    assert_not_includes query.documents, documents(:document_227)
  end

  test 'places count the Drucksachen naming each' do
    places = MapQuery.new(district: districts(:hamburg_nord)).places.index_by(&:first)

    assert_equal 1, places[locations(:heilwigstrasse).id][3]
    assert_equal 0, places[locations(:heilwigstrasse).id][4], 'the meeting is over'
  end

  test 'a Drucksache naming too many places is listed but not pinned' do
    stub_const(MapQuery, :MAX_PLACES, 1) do
      query = MapQuery.new

      assert_not_includes query.places.map(&:first), locations(:heilwigstrasse).id
      assert_includes query.places.map(&:first), locations(:stadtpark).id
      assert_includes query.documents_within(south: 53.5, west: 9.9, north: 53.7, east: 10.1), documents(:document_7)
      assert_equal 1, query.counts[:pinned]
      assert_equal 2, query.counts[:placed]
    end
  end

  test 'a place without a position is neither pinned nor counted' do
    locations(:stadtpark).update!(latitude: nil, longitude: nil)
    query = MapQuery.new

    assert_not_includes query.places.map(&:first), locations(:stadtpark).id
    assert_equal 1, query.counts[:placed]
  end

  test 'area counts take each Drucksache once per Stadtteil and Bezirk' do
    counts = MapQuery.new.area_counts

    # document_7 and document_227 both name a place in Barmbek-Nord.
    assert_equal 2, counts[:quarters]['Barmbek-Nord']
    assert_equal 1, counts[:quarters]['Groß Borstel']
    assert_operator counts[:districts].values.max, :>=, 2
  end

  private

  def stub_const(klass, name, value)
    old = klass.const_get(name)
    klass.send(:remove_const, name)
    klass.const_set(name, value)
    yield
  ensure
    klass.send(:remove_const, name)
    klass.const_set(name, old)
  end
end
