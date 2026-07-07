# frozen_string_literal: true

require 'test_helper'

class CommitteeTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @committee = @district.committees.create!(allris_id: 218, name: 'Regionalausschuss Barmbek-Uhlenhorst-Hohenfelde-Dulsberg')
    @source = file_fixture('au020.html').read
  end

  test 'recent_average_word_count averages the most recent meetings that have minutes' do
    older = @committee.meetings.create!(district: @district, allris_id: 9_201, title: 'Alt', date: Date.new(2024, 1, 1))
    older.agenda_items.create!(minutes: 'a b c') # 3
    newer = @committee.meetings.create!(district: @district, allris_id: 9_202, title: 'Neu', date: Date.new(2024, 2, 1))
    newer.agenda_items.create!(minutes: 'a b c d e') # 5

    assert_equal 4, @committee.recent_average_word_count(2)
  end

  test 'recent_average_word_count ignores meetings without minutes' do
    with = @committee.meetings.create!(district: @district, allris_id: 9_203, title: 'Mit', date: Date.new(2024, 3, 1))
    with.agenda_items.create!(minutes: 'a b c d') # 4
    # A newer meeting without minutes must not drag the average down.
    @committee.meetings.create!(district: @district, allris_id: 9_204, title: 'Ohne', date: Date.new(2024, 4, 1))

    assert_equal 4, @committee.recent_average_word_count
  end

  test 'recent_average_word_count is nil without any meetings that have minutes' do
    assert_nil @committee.recent_average_word_count
  end

  test 'recent_averages averages words and duration over the same recent meetings with minutes' do
    m1 = @committee.meetings.create!(district: @district, allris_id: 9_301, title: 'A', date: Date.new(2024, 1, 1),
                                     start_time: '18:00', end_time: '19:00') # 3600s
    m1.agenda_items.create!(minutes: 'a b c') # 3 words
    m2 = @committee.meetings.create!(district: @district, allris_id: 9_302, title: 'B', date: Date.new(2024, 2, 1),
                                     start_time: '18:00', end_time: '20:00') # 7200s
    m2.agenda_items.create!(minutes: 'a b c d e') # 5 words

    averages = @committee.recent_averages

    assert_equal 4, averages[:word_count]  # (3 + 5) / 2
    assert_equal 5400, averages[:duration] # (3600 + 7200) / 2
  end

  test 'recent_averages duration skips recent meetings without times but still counts their words' do
    timed = @committee.meetings.create!(district: @district, allris_id: 9_303, title: 'Timed', date: Date.new(2024, 3, 1),
                                        start_time: '18:00', end_time: '19:00') # 3600s
    timed.agenda_items.create!(minutes: 'a b') # 2 words
    untimed = @committee.meetings.create!(district: @district, allris_id: 9_304, title: 'Untimed', date: Date.new(2024, 4, 1))
    untimed.agenda_items.create!(minutes: 'a b c d') # 4 words

    averages = @committee.recent_averages

    assert_equal 3, averages[:word_count]  # (2 + 4) / 2, both counted
    assert_equal 3600, averages[:duration] # only the timed meeting
  end

  test 'recent_averages is empty without meetings that have minutes' do
    assert_nil @committee.recent_averages[:word_count]
    assert_nil @committee.recent_averages[:duration]
  end

  test 'retrieve_members_from_allris! creates members and memberships' do
    @committee.retrieve_members_from_allris!(@source)

    assert_equal 28, @committee.members.count
    assert_equal 28, @committee.memberships.count

    chair = @committee.memberships.joins(:member).find_by(members: { name: 'Christoph Reiffert' })
    assert_equal 'Vorsitzendes Mitglied', chair.role
    assert_equal 645, chair.member.allris_id
  end

  test 'members are scoped to the district and deduplicated by allris_id' do
    @committee.retrieve_members_from_allris!(@source)

    assert(@committee.members.all? { |member| member.district == @committee.district })

    assert_no_difference -> { @committee.district.members.count } do
      assert_no_difference -> { @committee.memberships.count } do
        @committee.retrieve_members_from_allris!(@source)
      end
    end
  end

  test 'retrieve_members_from_allris! sets memberships inactive when no longer listed, without destroying them' do
    @committee.retrieve_members_from_allris!(@source)

    stale = @committee.district.members.create!(allris_id: 999_999, name: 'Ehemalig')
    membership = @committee.memberships.create!(member: stale, role: 'Ausschussmitglied')

    @committee.retrieve_members_from_allris!(@source)

    assert membership.reload.inactive?
    assert_not_includes @committee.memberships.active, membership
  end

  test 'retrieve_members_from_allris! reactivates a membership when the member returns' do
    @committee.retrieve_members_from_allris!(@source)
    chair = @committee.memberships.joins(:member).find_by(members: { name: 'Christoph Reiffert' })
    chair.update!(inactive: true)

    @committee.retrieve_members_from_allris!(@source)

    assert_not chair.reload.inactive?
  end

  test 'retrieve_members_from_allris! ignores redirect responses' do
    assert_no_difference -> { @committee.memberships.count } do
      @committee.retrieve_members_from_allris!('Object moved')
    end
  end

  # One real au020 committee roster per district (see test/support). Parsing
  # every instance guards the committee crawler against instance-specific HTML
  # drift.
  AllrisFixtures.each_district do |slug, info|
    test "retrieve_members_from_allris! parses a #{slug} committee roster" do
      district = AllrisFixtures.build_district(slug)
      committee = district.committees.create!(allris_id: info['committee_id'], name: 'Ausschuss', allris_type: 'au')

      committee.retrieve_members_from_allris!(AllrisFixtures.page(slug, 'au020.html'))

      assert_operator committee.members.count, :>, 0, "#{slug}: expected members"
      assert_equal committee.members.count, committee.memberships.count,
                   "#{slug}: one membership per member"
      assert(committee.members.all? { |member| member.district == district },
             "#{slug}: members must be scoped to the district")
      assert(committee.memberships.all? { |membership| membership.role.present? },
             "#{slug}: every membership should carry a role")
    end
  end
end
