# frozen_string_literal: true

require 'test_helper'

class DistrictStatisticsTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @statistics = DistrictStatistics.new(@district)
  end

  test 'reads the decisions ALLRIS records' do
    assert_equal :adopted, DistrictStatistics.outcome('ungeändert beschlossen')
    assert_equal :adopted, DistrictStatistics.outcome('geändert beschlossen / überwiesen')
    assert_equal :rejected, DistrictStatistics.outcome('abgelehnt')
    assert_equal :withdrawn, DistrictStatistics.outcome('zurückgezogen / erledigt')
    assert_equal :withdrawn, DistrictStatistics.outcome('zur Kenntnis genommen')
    assert_nil DistrictStatistics.outcome('vertagt / verbleibt')
    assert_nil DistrictStatistics.outcome('an Fachausschuss verwiesen')
  end

  test 'an Antrag counts with the latest decision that settles it' do
    adopted = proposal('21-9001', 'vertagt' => meetings(:rega_ewi_oct), 'ungeändert beschlossen' => meetings(:bv_oct))
    settled = proposal('21-9002', 'abgelehnt' => meetings(:rega_ewi_oct), 'vertagt' => meetings(:bv_oct))
    pending = proposal('21-9003', 'überwiesen' => meetings(:rega_ewi_oct))

    outcomes = DistrictStatistics.new(@district).send(:outcomes)

    assert_equal :adopted, outcomes[adopted.id]
    assert_equal :rejected, outcomes[settled.id]
    assert_nil outcomes[pending.id]
  end

  test 'counts every outcome and leaves undecided Anträge open' do
    before = @statistics.proposal_outcomes
    proposal('21-9001', 'abgelehnt' => meetings(:bv_oct))
    proposal('21-9002')

    after = DistrictStatistics.new(@district).proposal_outcomes

    assert_equal DistrictStatistics::OUTCOMES.keys, after.keys
    assert_equal before[:rejected] + 1, after[:rejected]
    assert_equal before[:open] + 1, after[:open]
  end

  test 'the adoption rate leaves open Anträge out' do
    statistics = DistrictStatistics.new(@district)
    statistics.instance_variable_set(:@proposal_outcomes, { adopted: 3, rejected: 1, withdrawn: 0, open: 6 })

    assert_in_delta 0.75, statistics.adoption_rate
  end

  test 'no adoption rate before anything is decided' do
    @statistics.instance_variable_set(:@proposal_outcomes, { adopted: 0, rejected: 0, withdrawn: 0, open: 2 })

    assert_nil @statistics.adoption_rate
  end

  test 'lists every Stadtteil of the district, most named first' do
    documents(:document_7).update!(quarters: %w[Ohlsdorf Lokstedt])
    documents(:document_4).update!(quarters: ['Ohlsdorf'])

    counts = DistrictStatistics.new(@district).quarter_counts.to_h { |quarter, count| [quarter.name, count] }

    assert_equal 2, counts['Ohlsdorf']
    assert_equal 0, counts['Barmbek-Nord']
    assert_not counts.key?('Lokstedt'), 'Lokstedt is in Eimsbüttel'
    assert_equal 'Ohlsdorf', counts.keys.first
  end

  test 'counts a Drucksache once, however many meetings discussed it' do
    travel_to Date.new(2023, 12, 15) do
      # Both meetings are in October 2023.
      document = proposal('21-9001', 'vertagt' => meetings(:rega_ewi_oct), 'abgelehnt' => meetings(:bv_oct))
      before = DistrictStatistics.new(@district).monthly_timeline.to_h { |series| [series[:name], series[:data]] }
      document.agenda_items.destroy_all
      after = DistrictStatistics.new(@district).monthly_timeline.to_h { |series| [series[:name], series[:data]] }

      assert_equal 1, before['Davon Anträge']['Okt 23'] - after['Davon Anträge'].fetch('Okt 23', 0)
      assert_not before['Alle Drucksachen'].key?('Dez 23'), 'the running month is left out'
    end
  end

  test 'leaves out kinds of Drucksache too rare to chart per Fraktion' do
    Document.create!(district: @district, allris_id: 9001, number: '21-9001', title: 'Große Anfrage der SPD',
                     kind: Document::LARGE_INQUIRY_TYPES.first)

    series = DistrictStatistics.new(@district).party_series

    assert_equal DistrictStatistics::PARTIES.keys, series.pluck(:name)
    assert(series.none? { |row| row[:data].key?('Große Anfragen') })
  end

  private

  def proposal(number, decisions = {})
    document = Document.create!(district: @district, allris_id: number.delete('-').to_i, number:, title: "Antrag #{number}", kind: 'Antrag')
    decisions.each do |decision, meeting|
      AgendaItem.create!(meeting:, document:, decision:, title: document.title)
    end
    document
  end
end
