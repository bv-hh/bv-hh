# frozen_string_literal: true

require 'test_helper'

class MeetingHelperTest < ActionView::TestCase
  test 'days_until names today and tomorrow and counts days beyond' do
    today = Time.zone.today

    assert_equal 'heute', days_until(today)
    assert_equal 'morgen', days_until(today + 1)
    assert_equal 'in 12 Tagen', days_until(today + 12)
  end
end
