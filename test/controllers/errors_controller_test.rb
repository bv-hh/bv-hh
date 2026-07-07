# frozen_string_literal: true

require 'test_helper'

# Functional (controller) test rather than an integration test: the `/404` and
# `/500` routes are shadowed by the static pages in `public/`, which
# ActionDispatch::Static serves with a 200 before the request ever reaches this
# controller. A controller test bypasses the Rack middleware stack and lets us
# assert the actions set the correct error status.
class ErrorsControllerTest < ActionController::TestCase # rubocop:disable Rails/ActionControllerTestCase
  test 'GET not_found' do
    get :not_found
    assert_response :not_found
  end

  test 'GET exception' do
    get :exception
    assert_response :internal_server_error
  end
end
