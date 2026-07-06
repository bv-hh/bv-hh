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
end
