# frozen_string_literal: true

require 'test_helper'

class QuartersControllerTest < ActionDispatch::IntegrationTest
  setup { Quarter.reset! }
  teardown { Quarter.reset! }

  test 'GET show renders the Quarter and its documents' do
    get quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord')

    assert_response :success
    assert_includes @response.body, 'Barmbek-Nord'
    assert_includes @response.body, documents(:document_7).number
  end

  test 'GET show redirects a Quarter requested under the wrong district' do
    get '/altona/barmbek-nord'

    assert_redirected_to quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord')
    assert_equal 301, @response.status
  end

  test 'GET show redirects the bare slug to the canonical district-scoped path' do
    get '/barmbek-nord'

    assert_redirected_to quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord')
    assert_equal 301, @response.status
  end

  test 'GET show 404s for an unknown Quarter' do
    get "/#{districts(:hamburg_nord).to_param}/gibtsnicht"

    assert_response :not_found
  end

  # The catch-all route sits last inside scope '(:district)' precisely so that
  # it cannot swallow the resources declared above it.
  test 'the catch-all route does not shadow existing resources' do
    get documents_path(district: districts(:hamburg_nord))
    assert_response :success

    get meetings_path(district: districts(:hamburg_nord))
    assert_response :success

    get map_path(district: districts(:hamburg_nord))
    assert_response :success
  end

  test 'GET show as RSS renders the feed template' do
    get quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord', format: :rss)

    assert_response :success
    assert_equal 'application/rss+xml', @response.media_type
    assert_includes @response.body, '<rss'
    assert_includes @response.body, 'Barmbek-Nord'
  end

  test 'GET show as RSS keeps the format through the canonical redirect' do
    get '/altona/barmbek-nord.rss'

    assert_redirected_to quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord', format: :rss)
  end

  test 'GET show as RSS answers a conditional request with 304' do
    path = quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord', format: :rss)
    get path

    get path, headers: { 'HTTP_IF_NONE_MATCH' => @response.headers['ETag'] }
    assert_response :not_modified
  end

  test 'GET show as JSON returns the boundary and the markers for the page' do
    get quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord', format: :json)

    assert_response :success
    body = JSON.parse(@response.body)

    assert_equal %w[boundary bounds markers], body.keys.sort
    assert_kind_of Array, body['boundary']
    assert_equal 4, body['bounds'].flatten.size
  end

  test 'GET show as JSON only pins locations that lie in this Quarter' do
    get quarter_path(district: districts(:hamburg_nord), quarter: 'gross-borstel', format: :json)

    names = JSON.parse(@response.body)['markers'].pluck('name')

    assert_includes names, locations(:julius_vosseler).name
    assert_not_includes names, locations(:heilwigstrasse).name
  end

  # Only Hamburg-Nord exists in districts.yml, so Lokstedt (Bezirk 3) has no
  # District to build a canonical URL from, and therefore no page.
  test 'GET show 404s for a Quarter whose Bezirk has no District' do
    get "/#{districts(:hamburg_nord).to_param}/lokstedt"

    assert_response :not_found
  end

  # The bare single-segment form is matched by the district root, not by this
  # controller, so an unroutable Quarter falls back to the default district
  # rather than 404ing.
  test 'the bare slug of an unroutable Quarter falls back to the first district' do
    get '/lokstedt'

    assert_redirected_to root_with_district_path(district: District.first)
  end

  test 'GET show keeps a Quarter without documents renderable' do
    get quarter_path(district: districts(:hamburg_nord), quarter: 'ohlsdorf')

    assert_response :success
    assert_includes @response.body, 'keine Drucksachen erfasst'
  end
end
