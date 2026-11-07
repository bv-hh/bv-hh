# frozen_string_literal: true

require 'test_helper'

class MeetingHelperTest < ActionView::TestCase
  include FontAwesome::Sass::Rails::ViewHelpers

  test 'days_until names today and tomorrow and counts days beyond' do
    today = Time.zone.today

    assert_equal 'heute', days_until(today)
    assert_equal 'morgen', days_until(today + 1)
    assert_equal 'in 12 Tagen', days_until(today + 12)
  end

  test 'decision_label names the decision in short' do
    item = AgendaItem.new(decision: 'ungeändert beschlossen / überwiesen', meeting: Meeting.new(date: 1.week.ago.to_date))
    label = Nokogiri::HTML.fragment(decision_label(item)).at('span')

    assert_equal 'beschlossen', label.text.strip
    assert_equal 'text-success-emphasis', label['class']
  end

  test 'decision_label says a coming meeting has it on its agenda' do
    item = AgendaItem.new(meeting: Meeting.new(date: Time.zone.tomorrow))

    assert_includes decision_label(item), 'auf der Tagesordnung'
  end

  test 'decision_label no longer calls a meeting held today coming' do
    assert_nil decision_label(AgendaItem.new(meeting: Meeting.new(date: Time.zone.today)))
  end

  test 'decision_label leaves out a past meeting without a known decision' do
    assert_nil decision_label(AgendaItem.new(meeting: Meeting.new(date: 1.week.ago.to_date)))
    assert_nil decision_label(AgendaItem.new(decision: 'Unbekannt', meeting: Meeting.new(date: 1.week.ago.to_date)))
  end

  test 'listed_agenda_item shows the meeting that decided, not a later one that recorded nothing' do
    document = discussed([10.weeks.ago, 'abgelehnt'], [2.weeks.ago, ''])
    item = listed_agenda_item(document)

    assert_equal 10.weeks.ago.to_date, item.meeting.date
    assert_includes decision_label(item), 'abgelehnt'
  end

  test 'listed_agenda_item shows a coming meeting that has it on its agenda' do
    document = discussed([10.weeks.ago, 'beschlossen'], [1.week.from_now, ''])

    assert_includes decision_label(listed_agenda_item(document)), 'auf der Tagesordnung'
  end

  test 'listed_agenda_item falls back to the latest meeting without any decision' do
    document = discussed([10.weeks.ago, nil], [2.weeks.ago, nil])

    assert_equal 2.weeks.ago.to_date, listed_agenda_item(document).meeting.date
  end

  private

  # A Drucksache on the agenda of a meeting at each time, with that decision.
  def discussed(*meetings)
    committee = committees(:rega_ewi)
    document = Document.create!(district: committee.district, number: '21-9000', title: 'Antrag', allris_id: 1)
    meetings.each do |time, decision|
      meeting = Meeting.create!(committee:, district: committee.district, date: time.to_date, title: 'Sitzung', allris_id: rand(1_000_000))
      AgendaItem.create!(meeting:, document:, decision:, title: document.title)
    end
    document.reload
  end
end
