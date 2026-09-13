# frozen_string_literal: true

require 'test_helper'

class StreetsControllerTest < ActionDispatch::IntegrationTest
  test 'GET suggest returns matching streets as json' do
    get suggest_streets_path(q: 'heilwig')

    assert_response :success
    assert_equal 'application/json', @response.media_type

    suggestions = JSON.parse(@response.body)
    assert_equal ['Heilwigstraße'], suggestions.pluck('name')
  end

  test 'GET suggest reports the Quarters a street runs through' do
    get suggest_streets_path(q: 'julius')

    assert_equal [%w[Lokstedt], ['Groß Borstel']].flatten.sort,
                 JSON.parse(@response.body).first['quarters'].sort
  end

  test 'GET suggest normalizes punctuation before matching' do
    get suggest_streets_path(q: 'Julius-Vosseler')

    assert_equal ['Julius-Vosseler-Straße'], JSON.parse(@response.body).pluck('name')
  end

  test 'GET suggest returns nothing for a blank or too-short term' do
    get suggest_streets_path(q: '')
    assert_empty JSON.parse(@response.body)

    get suggest_streets_path
    assert_empty JSON.parse(@response.body)
  end

  test 'GET suggest treats LIKE wildcards as literal characters' do
    get suggest_streets_path(q: '%')

    assert_empty JSON.parse(@response.body)
  end
end
