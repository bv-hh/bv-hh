# frozen_string_literal: true

require 'test_helper'

class CommitteesControllerTest < ActionDispatch::IntegrationTest
  test 'GET index' do
    get committees_path(district: districts.first)
    assert_response :success
    assert_includes @response.body, committees(:rega_ewi).name
  end

  test 'GET show' do
    committee = committees(:rega_ewi)
    get committee_path(committee, district: districts.first)
    assert_response :success
    assert_includes @response.body, committee.name
  end
end
