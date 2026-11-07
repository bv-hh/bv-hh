# frozen_string_literal: true

require 'test_helper'

class DocumentOutcomeTest < ActiveSupport::TestCase
  setup do
    @document = Document.create!(district: districts(:hamburg_nord), number: '21-9000', title: 'Antrag', allris_id: 1)
    @committee = committees(:rega_ewi)
  end

  test 'reads each wording ALLRIS uses, and no guess for another' do
    assert_equal :adopted, AgendaItem.new(decision: 'ungeändert beschlossen / überwiesen').outcome
    assert_equal :withdrawn, AgendaItem.new(decision: 'zurückgezogen / erledigt').outcome
    assert_nil AgendaItem.new(decision: 'einstimmig').outcome
    assert_nil AgendaItem.new.outcome
  end

  test 'the latest settling decision counts, a later postponement does not reopen it' do
    adopted = discuss(10.weeks.ago, 'ungeändert beschlossen')
    discuss(6.weeks.ago, 'vertagt')
    discuss(2.weeks.ago, nil)

    assert_equal adopted, @document.reload.deciding_agenda_item
    assert_equal :adopted, @document.outcome
  end

  test 'without a settling decision the latest of any counts' do
    discuss(10.weeks.ago, 'überwiesen')
    postponed = discuss(6.weeks.ago, 'vertagt')

    assert_equal postponed, @document.reload.deciding_agenda_item
  end

  test 'a later settling decision replaces an earlier one' do
    discuss(10.weeks.ago, 'ungeändert beschlossen')
    discuss(6.weeks.ago, 'abgelehnt')

    assert_equal :rejected, @document.reload.outcome
  end

  test 'no outcome without a known decision' do
    discuss(6.weeks.ago, nil)

    assert_nil @document.reload.outcome
  end

  test 'the statistics count exactly the settling outcomes as decided' do
    assert_equal AgendaItem::SETTLING.sort, DistrictStatistics::SETTLED_AS.keys.sort
  end

  test 'the statistics count by the same rule' do
    assert_equal :adopted, DistrictStatistics.outcome('geändert beschlossen / überwiesen')
    assert_equal :withdrawn, DistrictStatistics.outcome('zur Kenntnis genommen')
    assert_nil DistrictStatistics.outcome('vertagt')
  end

  private

  def discuss(time, decision)
    meeting = Meeting.create!(committee: @committee, district: @committee.district, date: time.to_date, title: 'Sitzung', allris_id: rand(1_000_000))
    AgendaItem.create!(meeting:, document: @document, decision:, title: @document.title)
  end
end
