# frozen_string_literal: true

require 'test_helper'

class FeedQueryTest < ActiveSupport::TestCase
  setup { Quarter.reset! }
  teardown { Quarter.reset! }

  # --- selection semantics ----------------------------------------------------

  test 'matches documents mentioning a location in the selected Quarter' do
    documents = FeedQuery.new(quarters: ['Barmbek-Nord']).relation

    assert_includes documents, documents(:document_7)
  end

  test 'matches a street crossing into the Quarter, not just streets centred there' do
    # julius_vosseler's own point is in Lokstedt, but the register says it also
    # runs through Groß Borstel, so both must find it.
    assert_includes FeedQuery.new(quarters: ['Lokstedt']).relation, documents(:document_7)
    assert_includes FeedQuery.new(quarters: ['Groß Borstel']).relation, documents(:document_7)
  end

  test 'matches documents mentioning the selected street by name' do
    assert_includes FeedQuery.new(streets: ['Heilwigstraße']).relation, documents(:document_7)
  end

  test 'combines Quarters and streets as OR' do
    documents = FeedQuery.new(quarters: ['Barmbek-Nord'], streets: ['Julius-Vosseler-Straße']).relation

    assert_includes documents, documents(:document_7)
    assert_includes documents, documents(:document_227)
  end

  test 'returns a document once even when several of its locations match' do
    # document_7 has both heilwigstrasse and julius_vosseler attached.
    documents = FeedQuery.new(quarters: %w[Barmbek-Nord Lokstedt]).relation.to_a

    assert_equal 1, documents.count(documents(:document_7))
  end

  test 'excludes documents with no matching location' do
    assert_not_includes FeedQuery.new(quarters: ['Duvenstedt']).relation, documents(:document_7)
  end

  # --- filtering --------------------------------------------------------------

  test 'excludes noindex documents from both surfaces' do
    documents(:document_7).update!(noindex: true)

    assert_not_includes FeedQuery.new(quarters: ['Barmbek-Nord']).relation, documents(:document_7)
  end

  test 'excludes incomplete documents' do
    documents(:document_7).update!(title: nil)

    assert_not_includes FeedQuery.new(quarters: ['Barmbek-Nord']).relation, documents(:document_7)
  end

  # --- canonicalisation -------------------------------------------------------

  test 'canonicalises Quarter case so a lowercase param still matches' do
    query = FeedQuery.new(quarters: ['barmbek-nord'])

    assert_equal ['Barmbek-Nord'], query.quarters
    assert_includes query.relation, documents(:document_7)
  end

  test 'canonicalises street punctuation to the register normalisation' do
    assert_equal ['julius vosseler straße'], FeedQuery.new(streets: ['Julius-Vosseler-Straße ']).street_names
  end

  test 'drops unknown Quarters and streets' do
    query = FeedQuery.new(quarters: ['Gibtsnicht'], streets: ['Keinestraße'])

    assert_empty query.quarters
    assert_empty query.street_names
    assert_predicate query, :empty?
  end

  # --- params -----------------------------------------------------------------

  test 'from_params accepts the array form' do
    query = FeedQuery.from_params(quarters: ['Barmbek-Nord'], streets: ['Heilwigstraße'])

    assert_equal ['Barmbek-Nord'], query.quarters
    assert_equal ['heilwigstraße'], query.street_names
  end

  test 'from_params accepts a bare String' do
    assert_equal ['Barmbek-Nord'], FeedQuery.from_params(quarters: 'Barmbek-Nord').quarters
  end

  test 'from_params accepts the Hash form Rack builds for ?quarters[a]=x' do
    assert_equal ['Barmbek-Nord'], FeedQuery.from_params(quarters: { 'a' => 'Barmbek-Nord' }).quarters
  end

  test 'from_params ignores a param that is neither String, Array nor Hash' do
    assert_empty FeedQuery.from_params(quarters: 42).quarters
    assert_empty FeedQuery.from_params({}).quarters
  end

  test 'from_params drops nested values rather than passing them to SQL' do
    assert_empty FeedQuery.from_params(quarters: [['Barmbek-Nord']]).quarters
  end

  test 'from_params truncates past MAX_TERMS instead of failing' do
    names = Array.new(FeedQuery::MAX_TERMS + 10) { |i| "Quarter #{i}" } + ['Barmbek-Nord']
    values = FeedQuery.list_param(names)

    assert_equal FeedQuery::MAX_TERMS, values.size
    assert_not_includes values, 'Barmbek-Nord', 'the overflowing term is dropped, not the earlier ones'
  end

  test 'from_params strips blanks and deduplicates' do
    assert_equal ['Barmbek-Nord'], FeedQuery.list_param(['  Barmbek-Nord  ', 'Barmbek-Nord', '', '   '])
  end

  # --- empty selection --------------------------------------------------------

  test 'an unconfigured query matches nothing rather than everything' do
    query = FeedQuery.new

    assert_predicate query, :empty?
    assert_empty query.relation
  end

  # --- ordering and limits ----------------------------------------------------

  test 'orders by created_at descending for the feed' do
    created = FeedQuery.new(quarters: %w[Barmbek-Nord Lokstedt]).relation.map(&:created_at)

    assert_equal created.sort.reverse, created
  end

  test 'orders by document number for the HTML listing' do
    numbers = FeedQuery.new(quarters: %w[Barmbek-Nord Lokstedt]).relation(order: :number).map(&:number)

    assert_equal numbers.sort.reverse, numbers
  end

  test 'limit can be lifted so the listing can paginate instead' do
    assert_nothing_raised { FeedQuery.new(quarters: ['Barmbek-Nord']).relation(limit: nil).page(1) }
  end

  # --- cache key --------------------------------------------------------------

  test 'cache_key ignores the order terms were given in' do
    a = FeedQuery.new(quarters: %w[Barmbek-Nord Lokstedt])
    b = FeedQuery.new(quarters: %w[Lokstedt Barmbek-Nord])

    assert_equal a.cache_key, b.cache_key
  end

  test 'cache_key differs between different selections' do
    a = FeedQuery.new(quarters: ['Barmbek-Nord'])
    b = FeedQuery.new(quarters: ['Lokstedt'])

    assert_not_equal a.cache_key, b.cache_key
  end

  test 'description names both selection kinds' do
    description = FeedQuery.new(quarters: ['Barmbek-Nord'], streets: ['Heilwigstraße']).description

    assert_includes description, 'Barmbek-Nord'
    assert_includes description, 'Heilwigstraße'
  end

  # --- district ---------------------------------------------------------------

  test 'a district on its own feeds every Drucksache of that Bezirk' do
    query = FeedQuery.new(district: districts(:hamburg_nord))

    assert_not_predicate query, :empty?
    assert_includes query.relation, documents(:document_7)
  end

  test 'a district needs no location at all' do
    # document_4 has no document_locations, so only the district branch can
    # reach it.
    assert_includes FeedQuery.new(district: districts(:hamburg_nord)).relation, documents(:document_4)
    assert_not_includes FeedQuery.new(quarters: ['Barmbek-Nord']).relation, documents(:document_4)
  end

  test 'a district narrows a place selection rather than widening it' do
    district = districts(:hamburg_nord)
    with_district = FeedQuery.new(district: district, quarters: ['Barmbek-Nord']).relation.to_a
    without = FeedQuery.new(quarters: ['Barmbek-Nord']).relation.to_a

    assert_equal without, with_district, 'Barmbek-Nord is entirely inside Hamburg-Nord'
    assert_operator with_district.size, :<, FeedQuery.new(district: district).relation(limit: nil).count
  end

  test 'a district excludes places belonging to another Bezirk' do
    other = District.create!(name: 'Altona', order: 1, allris_base_url: 'https://example.test')

    assert_empty FeedQuery.new(district: other, quarters: ['Barmbek-Nord']).relation
  end

  test 'from_params resolves the district slug and ignores an unknown one' do
    assert_equal districts(:hamburg_nord), FeedQuery.from_params(district: 'hamburg-nord').district
    assert_nil FeedQuery.from_params(district: 'gibtsnicht').district
    assert_nil FeedQuery.from_params({}).district
  end

  test 'cache_key distinguishes districts' do
    other = District.create!(name: 'Altona', order: 1, allris_base_url: 'https://example.test')

    assert_not_equal FeedQuery.new(district: districts(:hamburg_nord)).cache_key,
                     FeedQuery.new(district: other).cache_key
  end

  test 'description names the district' do
    assert_includes FeedQuery.new(district: districts(:hamburg_nord)).description, 'Hamburg-Nord'
  end
end
