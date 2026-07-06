# frozen_string_literal: true

require 'test_helper'

class CommitteeMembersTest < ActionDispatch::IntegrationTest
  setup do
    @district = districts(:hamburg_nord)
    @committee = @district.committees.create!(allris_id: 218, name: 'Regionalausschuss BUHD')

    # The party (fr020) is the source of truth for members and their party;
    # the committee crawl (au020) then links them to the committee.
    @district.parties.create!(allris_id: 1120, name: 'GRÜNE').retrieve_from_allris!(file_fixture('fr020.html').read)
    @committee.retrieve_members_from_allris!(file_fixture('au020.html').read)
  end

  test 'committee show page lists active members with role and party' do
    get "/#{@district.to_param}/committees/#{@committee.id}"

    assert_response :success
    assert_select 'h3', text: 'Mitglieder'
    assert_select 'table tbody tr td', text: 'Christoph Reiffert'
    assert_select 'table tbody tr td', text: 'Vorsitzendes Mitglied'
    assert_select 'table tbody tr td', text: 'Fraktion Bündnis 90/DIE GRÜNEN'
  end

  test 'inactive members are hidden from the committee member list' do
    member = @district.members.find_by(name: 'Christoph Reiffert')
    member.update!(inactive: true)

    get "/#{@district.to_param}/committees/#{@committee.id}"

    assert_response :success
    assert_select 'table tbody tr td', text: 'Christoph Reiffert', count: 0
  end

  test 'member list is ordered by party size (regular members) then name' do
    # smaller party is alphabetically first to prove size beats alphabetical order
    small = @district.parties.create!(allris_id: 90, name: 'AAA-Fraktion')
    big = @district.parties.create!(allris_id: 91, name: 'ZZZ-Fraktion')
    @district.members.create!(allris_id: 601, name: 'Berta Big', party: big, kind: 'Fraktionsmitglied')
    @district.members.create!(allris_id: 602, name: 'Anton Big', party: big, kind: 'Fraktionsmitglied')
    @district.members.create!(allris_id: 603, name: 'Cesar Big', party: big, kind: 'Fraktionsmitglied')
    @district.members.create!(allris_id: 604, name: 'Xaver Small', party: small, kind: 'Fraktionsmitglied')
    Member.where(allris_id: 601..604).find_each { |m| @committee.memberships.create!(member: m, role: 'Ausschussmitglied') }

    get "/#{@district.to_param}/committees/#{@committee.id}"

    assert_response :success
    body = response.body
    # bigger party (3 regulars) before smaller (1), despite alphabetical order
    assert_operator body.index('Anton Big'), :<, body.index('Xaver Small')
    # within a party, name ascending
    assert_operator body.index('Anton Big'), :<, body.index('Berta Big')
    assert_operator body.index('Berta Big'), :<, body.index('Cesar Big')
  end

  test 'inactive memberships are hidden even when the member stays active' do
    membership = @committee.memberships.joins(:member).find_by(members: { name: 'Christoph Reiffert' })
    membership.update!(inactive: true)

    get "/#{@district.to_param}/committees/#{@committee.id}"

    assert_response :success
    assert_select 'table tbody tr td', text: 'Christoph Reiffert', count: 0
  end
end
