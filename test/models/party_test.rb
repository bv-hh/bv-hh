# frozen_string_literal: true

# == Schema Information
#
# Table name: parties
#
#  id          :integer          not null, primary key
#  allris_id   :integer
#  district_id :integer
#  name        :string
#  inactive    :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_parties_on_district_id                (district_id)
#  index_parties_on_district_id_and_allris_id  (district_id,allris_id) UNIQUE
#

require 'test_helper'

class PartyTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @party = @district.parties.create!(allris_id: 1120, name: 'GRÜNE')
    @source = file_fixture('fr020.html').read
  end

  test 'retrieve_from_allris! mirrors the party name and its members' do
    @party.retrieve_from_allris!(@source)

    assert_equal 'Fraktion Bündnis 90/DIE GRÜNEN', @party.name
    assert_equal 51, @party.members.count # one co-opted citizen has no published name

    chair = @party.members.find_by(allris_id: 1000510)
    assert_equal 'Fraktionsvorsitzende/r', chair.kind
    assert_not chair.inactive?
    assert_equal @district, chair.district
  end

  test 'members no longer listed are set inactive but not destroyed' do
    @party.retrieve_from_allris!(@source)

    former = @party.members.create!(district: @district, allris_id: 888_888, name: 'Ehemalig')

    assert_no_difference -> { @district.members.count } do
      @party.retrieve_from_allris!(@source)
    end

    assert former.reload.inactive?
    assert_equal @party, former.party
  end

  test 'retrieve_from_allris! ignores redirect responses' do
    assert_no_difference -> { @party.members.count } do
      @party.retrieve_from_allris!('Object moved')
    end
  end

  # One real fr020 party roster per district (see test/support). Parsing every
  # instance guards the party crawler against instance-specific HTML drift.
  AllrisFixtures.each_district do |slug, info|
    test "retrieve_from_allris! parses a #{slug} party roster" do
      district = AllrisFixtures.build_district(slug)
      party = district.parties.new(allris_id: info['party_id'])

      party.retrieve_from_allris!(AllrisFixtures.page(slug, 'fr020.html'))

      assert party.name.present?, "#{slug}: expected a party name"
      assert_operator party.members.count, :>, 0, "#{slug}: expected members"
      assert(party.members.all? { |member| member.district == district },
             "#{slug}: members must be scoped to the district")
      assert(party.members.all? { |member| member.name.present? },
             "#{slug}: every listed member should have a name")
    end
  end
end
