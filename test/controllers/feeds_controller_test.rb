# frozen_string_literal: true

require 'test_helper'

class FeedsControllerTest < ActionDispatch::IntegrationTest
  setup { Quarter.reset! }
  teardown { Quarter.reset! }

  test 'GET show renders the config page' do
    get feed_path

    assert_response :success
    assert_includes @response.body, 'Barmbek-Nord'
    assert_includes @response.body, 'noindex', 'the combinatorial URL space must not be crawled'
  end

  # districts.yml holds only Hamburg-Nord, so the other Bezirke the Quarter
  # fixtures reference have to exist for the ordering to be observable at all.
  test 'GET show groups the Quarters by Bezirk in District order' do
    District.create!(name: 'Eimsbüttel', order: 2, allris_base_url: 'https://example.test')
    District.create!(name: 'Wandsbek', order: 4, allris_base_url: 'https://example.test')

    get feed_path

    headings = @response.body.scan(/accordion-button[^>]*>\s*<span>([^<]*)</).flatten

    assert_equal %w[Eimsbüttel Hamburg-Nord Wandsbek], headings,
                 'Bezirk headings must follow District#order, not alphabetical order'
  end

  test 'GET show keeps Quarters whose Bezirk has no District record' do
    # Only Hamburg-Nord is in districts.yml, so Lokstedt (Bezirk 3) has no
    # District — but selecting it still filters correctly, so it must be offered.
    get feed_path

    assert_includes @response.body, 'Lokstedt'
  end

  test 'GET show puts each Bezirk in its own accordion panel' do
    get feed_path

    assert_equal Quarter.distinct.count(:district_number), @response.body.scan('accordion-item').size
    assert_includes @response.body, 'id="quarters-panel-hamburg-nord"'
  end

  test 'GET show collapses every panel when nothing is selected' do
    get feed_path

    assert_not_includes @response.body, 'accordion-collapse collapse show'
  end

  test 'GET show opens the panels holding a selection and counts them' do
    get feed_path(quarters: ['Barmbek-Nord'])

    panel = @response.body[/<div class="accordion-item">(?:(?!accordion-item).)*hamburg-nord.*?(?=<div class="accordion-item">|\z)/m]

    assert_includes panel, 'collapse show'
    assert_includes panel, 'badge bg-primary'
  end

  test 'GET show shows the generated feed URL once something is selected' do
    get feed_path(quarters: ['Barmbek-Nord'])

    assert_response :success
    assert_includes @response.body, 'feed.rss'
  end

  test 'GET show wraps the results in a turbo frame the form targets' do
    get feed_path(quarters: ['Barmbek-Nord'])

    assert_includes @response.body, 'data-turbo-frame="feed_results"', 'the form submits into the frame'
    assert_includes @response.body, 'id="feed_results"'
    assert_includes @response.body, 'data-turbo-action="advance"', 'so the URL stays shareable'
  end

  test 'GET show keeps the checkboxes outside the frame so a submit cannot clobber them' do
    get feed_path(quarters: ['Barmbek-Nord'])

    frame = @response.body[%r{<turbo-frame.*?</turbo-frame>}m]

    assert_predicate frame, :present?
    assert_not_includes frame, 'quarters[]'
  end

  test 'GET show answers a turbo frame request with the frame' do
    get feed_path(quarters: ['Barmbek-Nord']), headers: { 'Turbo-Frame' => 'feed_results' }

    assert_response :success
    assert_includes @response.body, 'id="feed_results"'
    assert_includes @response.body, 'feed.rss'
  end

  test 'GET show as RSS returns a feed of matching documents' do
    get feed_path(format: :rss, quarters: ['Barmbek-Nord'])

    assert_response :success
    assert_equal 'application/rss+xml', @response.media_type
    assert_includes @response.body, documents(:document_7).number
  end

  test 'GET show as RSS accepts a district as a whole-Bezirk feed' do
    get feed_path(format: :rss, district: districts(:hamburg_nord).to_param)

    assert_response :success
    assert_includes @response.body, 'Hamburg-Nord'
    assert_includes @response.body, documents(:document_7).number
  end

  # The config page is Hamburg-wide and has no district control, so a stray
  # ?district= is stripped there — but never on the feed itself.
  test 'GET show strips a district from the HTML page but keeps it on the feed' do
    get feed_path(district: districts(:hamburg_nord).to_param)
    assert_redirected_to feed_path

    get feed_path(format: :rss, district: districts(:hamburg_nord).to_param)
    assert_response :success
  end

  test 'GET show as RSS matches on street name too' do
    get feed_path(format: :rss, streets: ['Heilwigstraße'])

    assert_response :success
    assert_includes @response.body, documents(:document_7).number
  end

  test 'GET show as RSS with no selection returns a valid but empty feed' do
    get feed_path(format: :rss)

    assert_response :success
    assert_includes @response.body, '<rss'
    assert_not_includes @response.body, '<item>'
  end

  test 'GET show as RSS lists a document once even when several locations match' do
    get feed_path(format: :rss, quarters: ['Barmbek-Nord', 'Groß Borstel'])

    assert_equal 1, @response.body.scan(%r{<guid[^>]*>[^<]*#{documents(:document_7).id}</guid>}).size
  end

  test 'GET show as RSS is case insensitive for Quarters' do
    get feed_path(format: :rss, quarters: ['barmbek-nord'])

    assert_includes @response.body, documents(:document_7).number
  end

  test 'GET show as RSS survives a non-array param' do
    get feed_path(format: :rss, quarters: 'Barmbek-Nord')

    assert_response :success
    assert_includes @response.body, documents(:document_7).number
  end

  test 'GET show as RSS survives a hash-shaped param' do
    get '/feed.rss?quarters[x]=Barmbek-Nord'

    assert_response :success
  end

  test 'GET show as RSS survives a nested-array param' do
    get '/feed.rss?quarters[][]=Barmbek-Nord'

    assert_response :success
  end

  test 'GET show as RSS ignores unknown values' do
    get feed_path(format: :rss, quarters: ['Gibtsnicht'], streets: ['Keinestraße'])

    assert_response :success
    assert_not_includes @response.body, '<item>'
  end

  test 'GET show as RSS sets caching headers and answers a conditional request with 304' do
    get feed_path(format: :rss, quarters: ['Barmbek-Nord'])

    assert_predicate @response.headers['ETag'], :present?
    assert_predicate @response.headers['Last-Modified'], :present?
    assert_includes @response.headers['Cache-Control'], 'public'

    get feed_path(format: :rss, quarters: ['Barmbek-Nord']),
        headers: { 'HTTP_IF_NONE_MATCH' => @response.headers['ETag'] }
    assert_response :not_modified
  end

  test 'GET show as RSS gives different selections different ETags' do
    get feed_path(format: :rss, quarters: ['Barmbek-Nord'])
    barmbek = @response.headers['ETag']

    get feed_path(format: :rss, quarters: ['Groß Borstel'])

    assert_not_equal barmbek, @response.headers['ETag']
  end

  test 'GET show as RSS escapes document content rather than leaking entities' do
    get feed_path(format: :rss, quarters: ['Barmbek-Nord'])

    assert_not_includes @response.body, '&amp;nbsp;'
  end
end
