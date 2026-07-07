# frozen_string_literal: true

require 'test_helper'

class CommitteeTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @committee = @district.committees.create!(allris_id: 218, name: 'Regionalausschuss Barmbek-Uhlenhorst-Hohenfelde-Dulsberg')
    @source = file_fixture('au020.html').read
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
