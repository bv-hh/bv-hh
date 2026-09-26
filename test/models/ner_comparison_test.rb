# frozen_string_literal: true

require 'test_helper'

class NerComparisonTest < ActiveSupport::TestCase
  setup do
    [StreetGazetteer, QuarterGazetteer, PoiGazetteer].each(&:reset!)
    Document.delete_all
    @district = districts(:hamburg_nord)
  end

  teardown { [StreetGazetteer, QuarterGazetteer, PoiGazetteer].each(&:reset!) }

  test 'counts what both sides find, and what only one of them does' do
    document('Die Testallee am Teststadtpark in Ohlsdorfs Norden')
    # The model finds the park but misses the genitive, and adds a street name
    # the gazetteers never report.
    report = compare('Teststadtpark', 'Testalee')

    assert_equal 1, report.documents
    assert_equal({ both: 0, lost: 0, gained: 1 }, report.quarters.slice(:both, :lost, :gained))
    # Testallee on both, the park on both, the damaged spelling repairs to the
    # same Testallee and so costs nothing.
    assert_equal({ both: 2, lost: 0, gained: 0 }, report.places.slice(:both, :lost, :gained))
    assert_equal 0, report.lost_documents
  end

  test 'reports a place only the model finds as lost' do
    document('Schäden in der Testalee')

    report = compare('Testalee')

    assert_equal 1, report.places[:lost]
    assert_equal 1, report.lost_documents
    assert_match(/Testalee → Testallee/, report.places[:lost_examples].first)
  end

  test 'counts names that resolve to nothing' do
    document('Die BUKEA prüft')

    report = compare('BUKEA', 'Prüfauftrag')

    assert_equal 2, report.noise[:current]
    assert_equal 0, report.noise[:gazetteer]
  end

  test 'counts a name once whatever its case' do
    document('Die Testallee')

    assert_equal 1, compare('Testallee').names[:current]
  end

  test 'creates no locations' do
    document('Die Testallee am Teststadtpark')

    assert_no_difference('Location.count') { compare('Teststadtpark') }
  end

  private

  def compare(*names)
    NerComparison.new(ner: ->(_document, _text) { names }).run
  end

  def document(text)
    @allris_id = @allris_id.to_i + 1
    Document.create!(district: @district, title: 'Testdrucksache', full_text: text, allris_id: @allris_id)
  end
end
