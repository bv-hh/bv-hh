# frozen_string_literal: true

require 'test_helper'

class UpdateSlowlyChangingContentJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @district = District.create!(name: 'Slow-Bezirk', allris_base_url: 'https://allris.test')
  end

  test 'without a district it fans out one job per district' do
    assert_enqueued_jobs District.count, only: UpdateSlowlyChangingContentJob do
      UpdateSlowlyChangingContentJob.perform_now
    end
  end

  test 'it re-crawls stale meetings that never received a logged agenda' do
    stale = @district.meetings.create!(allris_id: 1, title: 'Ohne Agenda', date: 60.days.ago.to_date)
    # A meeting that already has a logged agenda item is done and must be skipped.
    logged = @district.meetings.create!(allris_id: 2, title: 'Mit Agenda', date: 60.days.ago.to_date)
    logged.agenda_items.create!(allris_id: 100, number: 'Ö1', title: 'TOP', minutes: '<p>fertig</p>')
    # A recent meeting without an agenda is not stale yet.
    @district.meetings.create!(allris_id: 3, title: 'Kürzlich', date: 5.days.ago.to_date)

    assert_enqueued_with(job: UpdateMeetingJob, args: [stale]) do
      UpdateSlowlyChangingContentJob.perform_now(@district)
    end
    assert_enqueued_jobs 1, only: UpdateMeetingJob
  end

  test 'it re-crawls incomplete agenda items within the logging window' do
    meeting = @district.meetings.create!(allris_id: 5, title: 'Sitzung', date: 60.days.ago.to_date)
    incomplete = meeting.agenda_items.create!(allris_id: 200, number: 'Ö1', title: 'TOP') # minutes & result still nil
    # An already-minuted item is complete and must be skipped.
    meeting.agenda_items.create!(allris_id: 201, number: 'Ö2', title: 'TOP2', minutes: '<p>Protokoll</p>')

    assert_enqueued_with(job: UpdateAgendaItemJob, args: [incomplete]) do
      UpdateSlowlyChangingContentJob.perform_now(@district)
    end
    assert_enqueued_jobs 1, only: UpdateAgendaItemJob
  end
end
