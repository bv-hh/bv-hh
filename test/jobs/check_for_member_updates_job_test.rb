# frozen_string_literal: true

require 'test_helper'

class CheckForMemberUpdatesJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test 'without a district it fans out one job per district' do
    assert_enqueued_jobs District.count, only: CheckForMemberUpdatesJob do
      CheckForMemberUpdatesJob.perform_now
    end
  end

  test 'for a district it enqueues a member update for each active committee only' do
    district = districts(:hamburg_nord)
    district.committees.create!(allris_id: 9_001, name: 'Aufgelöster Ausschuss', inactive: true)

    assert_enqueued_jobs district.committees.active.count, only: UpdateCommitteeMembersJob do
      CheckForMemberUpdatesJob.perform_now(district)
    end
  end
end
