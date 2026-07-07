# frozen_string_literal: true

require 'test_helper'

class UpdateAverageDurationsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test 'without a district it fans out one job per district' do
    assert_enqueued_jobs District.count, only: UpdateAverageDurationsJob do
      UpdateAverageDurationsJob.perform_now
    end
  end

  test "for a district it recomputes each committee's average meeting duration" do
    district = districts(:hamburg_nord)
    committee = committees(:rega_ewi) # its only meeting runs 18:00-19:15 => 4500s

    UpdateAverageDurationsJob.perform_now(district)

    assert_equal 4500, committee.reload.average_duration
  end
end
