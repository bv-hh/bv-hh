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
    item = AgendaItem.new(meeting: Meeting.new(date: Time.zone.today))

    assert_includes decision_label(item), 'auf der Tagesordnung'
  end

  test 'decision_label leaves out a past meeting without a known decision' do
    assert_nil decision_label(AgendaItem.new(meeting: Meeting.new(date: 1.week.ago.to_date)))
    assert_nil decision_label(AgendaItem.new(decision: 'Unbekannt', meeting: Meeting.new(date: 1.week.ago.to_date)))
  end
end
