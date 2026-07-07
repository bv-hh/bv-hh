# == Schema Information
#
# Table name: meetings
#
#  id           :integer          not null, primary key
#  district_id  :integer
#  title        :string
#  date         :date
#  time         :string
#  room         :string
#  location     :string
#  allris_id    :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  committee_id :integer
#  start_time   :time
#  end_time     :time
#  note         :text
#
# Indexes
#
#  index_meetings_on_allris_id     (allris_id)
#  index_meetings_on_committee_id  (committee_id)
#  index_meetings_on_district_id   (district_id)
#

# frozen_string_literal: true

require 'test_helper'

class MeetingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @district = districts(:hamburg_nord)
    @meeting = @district.meetings.create!(allris_id: 1_003_143, title: 'Sitzung der Bezirksversammlung', date: Date.new(2025, 12, 11))
  end

  test 'minutes_download_params extracts the public Niederschrift form values' do
    params = @meeting.send(:minutes_download_params, file_fixture('to010.html').read)

    assert_equal 'DOLFDNR=1392414&options=64', params
  end

  test 'minutes_download_params returns nil when there is no protocol form' do
    assert_nil @meeting.send(:minutes_download_params, '<html><body>no minutes</body></html>')
  end

  test 'duration is the number of seconds between start and end time' do
    meeting = meetings(:rega_ewi_oct) # 18:00 - 19:15

    assert_equal 4500, meeting.duration
  end

  test 'ends_at uses the recorded end time when present' do
    meeting = meetings(:rega_ewi_oct)

    assert_equal 19, meeting.ends_at.hour
    assert_equal 15, meeting.ends_at.min
    assert_equal meeting.date, meeting.ends_at.to_date
  end

  test "ends_at falls back to the committee's average duration when the end time is unknown" do
    committee = committees(:rega_ewi)
    committee.update!(average_duration: 1.hour.to_i)
    meeting = @district.meetings.create!(allris_id: 9_005, title: 'Offene Sitzung', date: Date.new(2024, 5, 1),
                                         committee:, start_time: '18:00', end_time: nil)

    assert_equal meeting.starts_at + 1.hour, meeting.ends_at
  end

  test 'ends_at falls back to four hours without an end time or average duration' do
    committee = @district.committees.create!(allris_id: 9_006, name: 'Ausschuss ohne Dauer', average_duration: nil)
    meeting = @district.meetings.create!(allris_id: 9_007, title: 'Sitzung', date: Date.new(2024, 5, 1),
                                         committee:, start_time: '18:00', end_time: nil)

    assert_equal meeting.starts_at + 4.hours, meeting.ends_at
  end

  # One real to010 agenda page per district (see test/support). Parsing every
  # instance guards the meeting crawler against instance-specific HTML drift.
  AllrisFixtures.each_district do |slug, info|
    test "retrieve_from_allris! parses a #{slug} meeting agenda" do
      district = AllrisFixtures.build_district(slug)
      meeting = AllrisFixtures.stub_network(district.meetings.new(allris_id: info['meeting_id']))

      meeting.retrieve_from_allris!(AllrisFixtures.page(slug, 'to010.html'))

      assert_predicate meeting, :persisted?
      assert meeting.title.present?, "#{slug}: expected a meeting title"
      assert_not_nil meeting.date, "#{slug}: expected a meeting date"
      assert_not_nil meeting.start_time, "#{slug}: expected a start time"
      assert_not_nil meeting.committee, "#{slug}: expected a committee to be linked"
      assert meeting.committee.name.present?, "#{slug}: expected a committee name"
      assert_operator meeting.agenda_items.count, :>, 0, "#{slug}: expected agenda items"
      # Agenda rows that link a document should have one attached.
      assert_operator meeting.agenda_items.where.not(document_id: nil).count, :>, 0,
                      "#{slug}: expected at least one agenda item with a document"
    end
  end

  test 'retrieve_from_allris! schedules follow-up crawls for agenda items and their documents' do
    district = AllrisFixtures.build_district('hamburg_nord')
    meeting = AllrisFixtures.stub_network(district.meetings.new(allris_id: 1_003_201))

    # Logged agenda items get an UpdateAgendaItemJob; documents newly created for
    # linked rows get an UpdateDocumentJob so their content is fetched later.
    assert_enqueued_with(job: UpdateAgendaItemJob) do
      assert_enqueued_with(job: UpdateDocumentJob) do
        meeting.retrieve_from_allris!(AllrisFixtures.page('hamburg_nord', 'to010.html'))
      end
    end

    assert_operator meeting.agenda_items.logged.count, :>, 0
  end
end
