# frozen_string_literal: true

require 'test_helper'

class UpdateCommitteeAveragesJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test 'without a district it fans out one job per district' do
    assert_enqueued_jobs District.count, only: UpdateCommitteeAveragesJob do
      UpdateCommitteeAveragesJob.perform_now
    end
  end

  test "for a district it recomputes each committee's average meeting duration" do
    district = districts(:hamburg_nord)
    committee = committees(:rega_ewi) # its only meeting runs 18:00-19:15 => 4500s

    UpdateCommitteeAveragesJob.perform_now(district)

    assert_equal 4500, committee.reload.average_duration
  end

  test "for a district it caches each committee's average minutes word count" do
    district = districts(:hamburg_nord)
    committee = committees(:rega_ewi)
    meetings(:rega_ewi_oct).agenda_items.create!(minutes: 'a b c d e') # 5 words

    UpdateCommitteeAveragesJob.perform_now(district)

    assert_equal 5, committee.reload.average_word_count
  end
end
