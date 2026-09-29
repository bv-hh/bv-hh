# frozen_string_literal: true

require 'test_helper'

# Pages that only exist within a district, requested without one. Bots probe
# these, and they used to end in a 500 via a SystemStackError in the error log.
class DistrictRequiredTest < ActionDispatch::IntegrationTest
  %w[/documents /meetings /committees /parties /statistics].each do |path|
    test "GET #{path} without a district is a 404" do
      get path

      assert_response :not_found
    end
  end

  test 'an unknown document is a 404, not a 500' do
    get document_path('999999999', district: districts(:hamburg_nord))

    assert_response :not_found
  end
end
