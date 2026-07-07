# frozen_string_literal: true

require 'test_helper'

# Covers the crawler entry points: the methods that read an ALLRIS index page and
# schedule the detail crawls. Each takes an injectable `source` (mirroring the
# retrieve_from_allris! parsers), so these run against captured index pages with
# no network. Real HH-Nord index pages live in test/fixtures/files/.
class DistrictTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @district = District.create!(name: 'Test-Bezirk', allris_base_url: 'https://allris.test',
                                 oldest_allris_document_id: 0, oldest_allris_meeting_date: '2019-01-01',
                                 first_legislation_number: '21-0001')
  end

  # --- check_for_document_updates (vo040) ---

  test 'check_for_document_updates enqueues an update for every document newer than the latest known id' do
    source = file_fixture('vo040.html').read
    top = latest_volfdnr(source)
    @district.update!(oldest_allris_document_id: top - 3)

    assert_difference -> { @district.documents.count }, 3 do
      assert_enqueued_jobs 3, only: UpdateDocumentJob do
        @district.check_for_document_updates(source)
      end
    end

    assert_equal [top, top - 1, top - 2], @district.documents.order(allris_id: :desc).pluck(:allris_id)
  end

  test 'check_for_document_updates does nothing when already up to date' do
    source = file_fixture('vo040.html').read
    @district.update!(oldest_allris_document_id: latest_volfdnr(source))

    assert_no_difference -> { @district.documents.count } do
      assert_no_enqueued_jobs do
        @district.check_for_document_updates(source)
      end
    end
  end

  # --- check_for_meetings_in_month (si010_e) ---

  test 'check_for_meetings_in_month enqueues meetings with an agenda and parses agenda-less rows inline' do
    source = file_fixture('si010_e.html').read

    assert_enqueued_jobs 5, only: UpdateMeetingJob do
      @district.check_for_meetings_in_month(Date.new(2023, 10, 1), source)
    end

    # Rows without an agenda link get their metadata parsed directly instead of
    # being deferred to a job.
    inline = @district.meetings.where.not(title: nil).where.not(start_time: nil)
    assert inline.any?, 'expected agenda-less meetings to be parsed inline'
    assert(inline.all? { |meeting| meeting.date.year == 2023 && meeting.date.month == 10 })
  end

  # --- check_for_party_updates (fr010) ---

  test 'check_for_party_updates creates each listed party and enqueues a refresh' do
    source = file_fixture('fr010.html').read

    assert_difference -> { @district.parties.count }, 10 do
      assert_enqueued_jobs 10, only: UpdatePartyJob do
        @district.check_for_party_updates(source)
      end
    end

    assert_includes @district.parties.pluck(:name), 'Fraktion Bündnis 90/DIE GRÜNEN'
  end

  test 'check_for_party_updates is idempotent across runs' do
    source = file_fixture('fr010.html').read
    @district.check_for_party_updates(source)

    assert_no_difference -> { @district.parties.count } do
      @district.check_for_party_updates(source)
    end
  end

  private

  def latest_volfdnr(source)
    Nokogiri::HTML.parse(source.dup.force_encoding('ISO-8859-1'))
                  .css('tr.zl12 a').first['href'][/VOLFDNR=(\d+)/, 1].to_i
  end
end
