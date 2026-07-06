# frozen_string_literal: true

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
require 'test_helper'

class MeetingTest < ActiveSupport::TestCase
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

  test 'sync_attendance! matches members, flags substitutes and ignores administration' do
    gruene = @district.parties.create!(allris_id: 1, name: 'GRÜNE-Fraktion')
    spd = @district.parties.create!(allris_id: 2, name: 'SPD-Fraktion')
    cdu = @district.parties.create!(allris_id: 3, name: 'CDU-Fraktion')
    chair = @district.members.create!(allris_id: 10, name: 'Hans Müller', party: spd)
    gruene_schmidt = @district.members.create!(allris_id: 11, name: 'Anna Schmidt', party: gruene)
    spd_schmidt = @district.members.create!(allris_id: 12, name: 'Bernd Schmidt', party: spd)
    stand_in = @district.members.create!(allris_id: 13, name: 'Carla Vertreter', party: cdu)

    @meeting.sync_attendance!(attendance_text)

    assert_equal 5, @meeting.attendances.count
    assert_equal 4, @meeting.attendances.matched.count

    # surname + party disambiguation picks the right Schmidt
    assert_equal gruene_schmidt, @meeting.attendances.find_by(party_hint: 'GRÜNE').member
    assert_includes @meeting.attendances.where(member: spd_schmidt).pluck(:party_hint), 'SPD'
    assert_equal chair, @meeting.attendances.find_by(role: 'Vorsitzendes Mitglied').member

    # the stand-in is matched (a district member) and flagged as substitute
    substitute = @meeting.attendances.substitutes.sole
    assert_equal stand_in, substitute.member

    # unknown attendee is kept without a member; administration is dropped
    unknown = @meeting.attendances.find_by(member: nil)
    assert_equal 'Herr Unbekannt', unknown.name
    assert_not @meeting.attendances.exists?(name: 'Frau Amt')
  end

  test 'sync_attendance! is idempotent' do
    @district.members.create!(allris_id: 10, name: 'Hans Müller', party: @district.parties.create!(allris_id: 2, name: 'SPD-Fraktion'))
    @meeting.sync_attendance!(attendance_text)

    assert_no_difference -> { Attendance.count } do
      @meeting.sync_attendance!(attendance_text)
    end
  end

  private

  def attendance_text
    <<~MINUTES
      Vorsitz
      Herr Müller                              SPD-Fraktion                     Vorsitzendes Mitglied
      stimmberechtigte Mitglieder
      Frau Schmidt                             GRÜNE-                           Ausschussmitglied
                                               Fraktion
      Frau Schmidt                             SPD-Fraktion                     Ausschussmitglied
      Herr Vertreter                           CDU-Fraktion für Frau            Stellvertr. Ausschussmitglied
                                                              Lange
      Herr Unbekannt                           FDP-Fraktion                     Ausschussmitglied
      Verwaltung
      Frau Amt                                 Bezirksamt                       Dezernat Steuerung
      Protokollführung
      Frau Schreiber                           Bezirksamt                       Protokollführung
    MINUTES
  end
end
