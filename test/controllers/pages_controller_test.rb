# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  %i[home imprint privacy about].each do |action|
    test "GET #{action}" do
      get action
      assert_response :success
    end
  end
end
