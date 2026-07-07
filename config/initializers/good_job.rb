# frozen_string_literal: true

Rails.application.configure do
  config.good_job.max_threads = 5

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
