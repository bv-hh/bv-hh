# frozen_string_literal: true

require 'test_helper'

class UpdateChangingContentJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test 'without a district it fans out one job per district' do
    assert_enqueued_jobs District.count, only: UpdateChangingContentJob do
      UpdateChangingContentJob.perform_now
    end
  end

  test 'for a district it schedules re-crawls of recently created documents and meetings' do
    district = districts(:hamburg_nord)
    # An incomplete document created just now: needs_update? is true, so it should
    # be re-fetched.
    district.documents.create!(allris_id: 9_003)
    district.meetings.create!(allris_id: 9_004, title: 'Neue Sitzung', date: Time.zone.today, committee: committees(:rega_ewi))

    assert_enqueued_with(job: UpdateDocumentJob) do
      assert_enqueued_with(job: UpdateMeetingJob) do
        UpdateChangingContentJob.perform_now(district)
      end
    end
  end
end
