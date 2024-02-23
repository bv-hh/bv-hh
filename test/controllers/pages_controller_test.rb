# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  test 'GET root' do
    get root_path
    assert_response :success
  end

  %i[imprint privacy about].each do |action|
    test "GET #{action}" do
      get send("#{action}_path".to_sym)
      assert_response :success
    end
  end
end
