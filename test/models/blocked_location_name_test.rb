# frozen_string_literal: true

require 'test_helper'

class BlockedLocationNameTest < ActiveSupport::TestCase
  setup { BlockedLocationName.reset! }
  teardown { BlockedLocationName.reset! }

  test 'blocked? matches regardless of case and punctuation' do
    BlockedLocationName.create!(name: 'Bezirk Hamburg-Nord')
    BlockedLocationName.reset!

    assert BlockedLocationName.blocked?('Bezirk Hamburg-Nord')
    assert BlockedLocationName.blocked?('bezirk hamburg nord')
    assert BlockedLocationName.blocked?('  BEZIRK  HAMBURG-NORD ')
  end

  test 'blocked? is false for anything not listed, blank included' do
    assert_not BlockedLocationName.blocked?('Heilwigstraße')
    assert_not BlockedLocationName.blocked?('')
    assert_not BlockedLocationName.blocked?(nil)
  end

  test 'the normalized name is unique across spellings' do
    BlockedLocationName.create!(name: 'BUKEA')

    assert_raises(ActiveRecord::RecordInvalid) { BlockedLocationName.create!(name: 'bukea') }
  end

  test 'Location.blocked? consults the table as well as the constant' do
    assert Location.blocked?('Hamburg'), 'precondition: the constant still applies'
    assert_not Location.blocked?('BUKEA')

    BlockedLocationName.create!(name: 'BUKEA')
    BlockedLocationName.reset!

    assert Location.blocked?('BUKEA')
  end
end
