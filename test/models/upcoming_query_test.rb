# frozen_string_literal: true

require 'test_helper'

class UpcomingQueryTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @today = Date.new(2026, 10, 2)
    @area_committee = @district.committees.create!(name: 'Regionalausschuss Langenhorn-Fuhlsbüttel-Ohlsdorf-Alsterdorf-Groß Borstel')
    @about_ohlsdorf = document_in('Ohlsdorf')
    Quarter.reset!
  end

  def document_in(quarter, topics: [])
    @district.documents.create!(allris_id: 9_800 + Document.unscoped.count, title: "Drucksache zu #{quarter}",
                                quarters: [quarter], topics:)
  end

  def meeting(committee, date: @today + 5.days, items: [])
    meeting = @district.meetings.create!(committee:, title: "Sitzung #{committee.name}", date:, start_time: '18:00')
    items.each_with_index do |(title, document), index|
      meeting.agenda_items.create!(number: "Ö #{index + 1}", title:, document:)
    end
    meeting
  end

  def upcoming(**selection)
    UpcomingQuery.new(FeedQuery.new(**selection), today: @today)
  end

  test 'a meeting with an item about the Stadtteil is upcoming, with that item' do
    bv = meeting(committees(:bv), items: [['Eröffnung', nil], ['Neue Bänke in Ohlsdorf', @about_ohlsdorf]])

    entry = upcoming(quarters: ['Ohlsdorf']).entries.sole

    assert_equal bv, entry.meeting
    assert_equal ['Neue Bänke in Ohlsdorf'], entry.items.map(&:title)
    assert_not entry.area
  end

  test 'a meeting of another committee without such an item is not' do
    meeting(committees(:bv), items: [['Haushalt', document_in('Winterhude')]])

    assert_empty upcoming(quarters: ['Ohlsdorf']).entries
  end

  test "the Stadtteil's area committee is always upcoming, even before its agenda is out" do
    with_agenda = meeting(@area_committee, items: [['Öffentliche Fragestunde', nil], ['Verschiedenes', nil]])
    without = meeting(@area_committee, date: @today + 12.days)

    entries = upcoming(quarters: ['Ohlsdorf']).entries

    assert_equal [with_agenda, without], entries.map(&:meeting)
    assert entries.all?(&:area)
    assert_empty entries.first.items
    assert_equal 'Öffentliche Fragestunde', entries.first.question_time.title
    assert_predicate entries.first, :agenda?
    assert_not_predicate entries.last, :agenda?
  end

  test 'only the next two weeks' do
    meeting(@area_committee, date: @today - 1.day)
    meeting(@area_committee, date: @today + 15.days)
    today = meeting(@area_committee, date: @today)

    assert_equal [today], upcoming(quarters: ['Ohlsdorf']).entries.map(&:meeting)
  end

  test 'a topic narrows the items and leaves out area meetings without one about it' do
    cycling = document_in('Ohlsdorf', topics: %w[radverkehr])
    meeting(@area_committee, items: [['Bänke', @about_ohlsdorf]])
    bv = meeting(committees(:bv), items: [['Radweg', cycling], ['Bänke', @about_ohlsdorf]])

    entry = upcoming(quarters: ['Ohlsdorf'], topics: %w[radverkehr]).entries.sole

    assert_equal bv, entry.meeting
    assert_equal ['Radweg'], entry.items.map(&:title)
  end

  test 'nothing for an empty selection' do
    meeting(committees(:bv), items: [['Bänke', @about_ohlsdorf]])

    assert_empty upcoming.entries
  end
end
