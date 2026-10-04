# frozen_string_literal: true

Rails.application.configure do
  config.good_job.max_threads = 8

  # Finished jobs are kept for the dashboard, and cleaned up by GoodJob itself.
  # The default of 14 days lets a topic reassignment (one job per document,
  # ~70k) or a few nights of re-fetching pile up hundreds of thousands of rows;
  # three days is plenty to look into a failure.
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 3.days.to_i

  config.good_job.enable_cron = true

  config.good_job.cron = {
    check_for_document_updates: {
      class: 'CheckForDocumentUpdatesJob',
      cron: '0 42 * * * *',
    },
    check_for_meeting_updates: {
      class: 'CheckForMeetingUpdatesJob',
      cron: '0 42 16 * * *',
    },
    update_changing_content: {
      class: 'UpdateChangingContentJob',
      cron: '0 23 */4 * * *',
    },
    update_slowly_changing_content: {
      class: 'UpdateSlowlyChangingContentJob',
      cron: '0 17 3 * * *',
    },
    update_todays_meetings: {
      class: 'UpdateTodaysMeetingsJob',
      cron: '0 7 * * * *',
    },
    check_for_party_updates: {
      class: 'CheckForPartyUpdatesJob',
      cron: '0 12 5 * * *',
    },
    check_for_member_updates: {
      class: 'CheckForMemberUpdatesJob',
      cron: '0 42 5 * * *',
    },
    generate_sitemap: {
      class: 'GenerateSitemapJob',
      cron: '0 59 2 * * *',
    },
    # Ends by 04:15 (RefetchDocumentsJob::WINDOW, 5 hours during the catch-up;
    # 01:45 at the usual 2.5 hours, before the sitemap at 02:59).
    # All times here are UTC.
    refetch_documents: {
      class: 'RefetchDocumentsJob',
      cron: '0 15 23 * * *',
    },
    # After the refetch and the sitemap, so the day's changes are in and the
    # model has the machine to itself.
    embed_documents: {
      class: 'EmbedDocumentsJob',
      cron: '0 7 4 * * *',
    },
    update_committee_averages: {
      class: 'UpdateCommitteeAveragesJob',
      cron: '0 23 1 1 * *',
    },
    # extract_document_locations_job: {
    #  class: 'ExtractDocumentLocationsJob',
    #  cron: '0 39 1 * * *',
    # },
  }
end
