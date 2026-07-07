# frozen_string_literal: true

require 'test_helper'

class UpdateTodaysMeetingsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test 'without a district it fans out per district and purges orphaned agenda items' do
    orphan = AgendaItem.new(number: 'Ö1', title: 'Verwaist')
    orphan.save!(validate: false) # meeting_id is nil: a leftover from a re-crawled agenda

    assert_enqueued_jobs District.count, only: UpdateTodaysMeetingsJob do
      UpdateTodaysMeetingsJob.perform_now
    end

    assert_not AgendaItem.exists?(orphan.id), 'orphaned agenda item should be purged'
  end

  test 'for a district it enqueues an update for meetings happening today' do
    district = districts(:hamburg_nord)
    district.meetings.create!(allris_id: 9_002, title: 'Sitzung heute', date: Time.zone.today, committee: committees(:rega_ewi))

    assert_enqueued_with(job: UpdateMeetingJob) do
      UpdateTodaysMeetingsJob.perform_now(district)
    end
  end

  test 'it does not enqueue meetings on other days' do
    district = districts(:hamburg_nord) # fixture meetings are dated 2023

    assert_no_enqueued_jobs only: UpdateMeetingJob do
      UpdateTodaysMeetingsJob.perform_now(district)
    end
  end
end
