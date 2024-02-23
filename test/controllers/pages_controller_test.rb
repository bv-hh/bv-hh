# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionController::TestCase

  %i[home imprint privacy about].each do |action|
    test "GET #{action}" do
      get action
      assert_response :success
    end
  end
end
