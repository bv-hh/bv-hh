# frozen_string_literal: true

require 'test_helper'

class PartiesTest < ActionDispatch::IntegrationTest
  setup do
    @district = districts(:hamburg_nord)
  end

  test 'index orders parties by regular member count and shows that count' do
    big = @district.parties.create!(allris_id: 1, name: 'Große Fraktion')
    3.times { |i| big.members.create!(district: @district, allris_id: 100 + i, name: "Regular #{i}", kind: 'Fraktionsmitglied') }
    big.members.create!(district: @district, allris_id: 200, name: 'Zugewählt', kind: Member::CO_OPTED_KINDS.first)

    small = @district.parties.create!(allris_id: 2, name: 'Kleine Fraktion')
    small.members.create!(district: @district, allris_id: 300, name: 'Einzelkämpfer', kind: 'Fraktionsmitglied')

    get "/#{@district.to_param}/parties"

    assert_response :success
    # ordered by regular members desc: big (3, co-opted excluded) before small (1)
    assert_operator response.body.index('Große Fraktion'), :<, response.body.index('Kleine Fraktion')
    assert_select 'table tbody tr', 2
    assert_select 'table tbody tr:first-child td.text-end', text: '3'
  end

  test 'show lists members with committee memberships as secondary info' do
    party = @district.parties.create!(allris_id: 1120, name: 'GRÜNE')
    party.retrieve_from_allris!(file_fixture('fr020.html').read)

    committee = @district.committees.create!(allris_id: 218, name: 'Regionalausschuss BUHD')
    member = party.members.regular.by_name.first
    committee.memberships.create!(member:, role: 'Ausschussmitglied')

    get "/#{@district.to_param}/parties/#{party.to_param}"

    assert_response :success
    assert_select 'h2', text: 'Fraktion Bündnis 90/DIE GRÜNEN'
    assert_select 'table tbody tr td', text: member.name
    assert_select 'td a', text: 'Regionalausschuss BUHD'
  end

  test 'show orders regular members before co-opted ones' do
    party = @district.parties.create!(allris_id: 1120, name: 'GRÜNE')
    party.retrieve_from_allris!(file_fixture('fr020.html').read)

    # alphabetically last regular member still precedes the first co-opted one
    last_regular = party.members.regular.order(name: :desc).first
    first_co_opted = party.members.co_opted.by_name.first

    get "/#{@district.to_param}/parties/#{party.to_param}"

    assert_response :success
    assert_operator response.body.index(last_regular.name), :<, response.body.index(first_co_opted.name)
  end

  test 'show hides inactive members and inactive memberships' do
    party = @district.parties.create!(allris_id: 1120, name: 'GRÜNE')
    party.retrieve_from_allris!(file_fixture('fr020.html').read)
    gone = party.members.regular.by_name.first
    gone.update!(inactive: true)

    get "/#{@district.to_param}/parties/#{party.to_param}"

    assert_response :success
    assert_select 'table tbody tr td', text: gone.name, count: 0
  end
end
