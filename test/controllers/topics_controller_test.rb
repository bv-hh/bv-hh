# frozen_string_literal: true

require 'test_helper'

class TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Document.update_all(topics: [])
    documents(:document_7).update_columns(topics: %w[strassenverkehr]) # rubocop:disable Rails/SkipsModelValidations
    documents(:document_4).update_columns(topics: %w[gruen]) # rubocop:disable Rails/SkipsModelValidations
  end

  test 'GET show lists the documents of the district tagged with the topic' do
    get topic_path(topic: 'strassenverkehr', district: districts(:hamburg_nord))

    assert_response :success
    assert_includes @response.body, documents(:document_7).number
    assert_not_includes @response.body, documents(:document_4).number
  end

  test 'GET show without a district covers all of Hamburg' do
    get '/themen/strassenverkehr'

    assert_response :success
    assert_includes @response.body, documents(:document_7).number
    assert_includes @response.body, 'allen Hamburger Bezirken'
  end

  test 'GET show redirects a topic key to its slug' do
    documents(:document_7).update_columns(topics: %w[kinder_jugend]) # rubocop:disable Rails/SkipsModelValidations

    get "/#{districts(:hamburg_nord).to_param}/themen/kinder_jugend"

    assert_redirected_to topic_path(topic: 'kinder-jugend', district: districts(:hamburg_nord))
    assert_equal 301, @response.status
  end

  test 'GET show redirects an unknown district to the Hamburg-wide page' do
    get '/gibtsnicht/themen/strassenverkehr'

    assert_redirected_to '/themen/strassenverkehr'
  end

  test 'GET show 404s for an unknown topic' do
    get "/#{districts(:hamburg_nord).to_param}/themen/gibtsnicht"

    assert_response :not_found
  end

  test 'GET show links the feed for the same selection' do
    get topic_path(topic: 'strassenverkehr', district: districts(:hamburg_nord))

    assert_includes @response.body,
                    CGI.escapeHTML(feed_path(format: :rss, district: districts(:hamburg_nord).to_param, topics: ['strassenverkehr']))
  end

  test 'the topic route does not shadow Quarter pages' do
    Quarter.reset!
    get quarter_path(district: districts(:hamburg_nord), quarter: 'barmbek-nord')

    assert_response :success
  ensure
    Quarter.reset!
  end

  test 'GET show lists a district by number and Hamburg by created_at' do
    documents(:document_7).update_columns(topics: %w[kultur]) # rubocop:disable Rails/SkipsModelValidations
    documents(:document_227).update_columns(topics: %w[kultur]) # rubocop:disable Rails/SkipsModelValidations
    Document.where(id: documents(:document_7)).update_all(created_at: 3.days.ago)
    Document.where(id: documents(:document_227)).update_all(created_at: 1.hour.ago)
    first = ->(a, b) { @response.body.index(a.number) < @response.body.index(b.number) }

    get topic_path(topic: 'kultur', district: districts(:hamburg_nord))

    assert first.call(documents(:document_7), documents(:document_227)), 'higher number first within a district'

    get '/themen/kultur'

    assert first.call(documents(:document_227), documents(:document_7)), 'newest first across Hamburg'
  end

  test 'GET show pages the list' do
    get topic_path(topic: 'strassenverkehr', district: districts(:hamburg_nord), page: 2)

    assert_response :success
    assert_includes @response.body, 'keine Drucksachen erfasst'
  end

  test 'GET show is not indexed when the topic has no documents, and is otherwise' do
    get topic_path(topic: 'kultur', district: districts(:hamburg_nord))
    assert_includes @response.body, 'noindex'

    get topic_path(topic: 'strassenverkehr', district: districts(:hamburg_nord))
    assert_not_includes @response.body, 'noindex'
  end

  test 'GET show links only to other topics that have documents' do
    get topic_path(topic: 'strassenverkehr', district: districts(:hamburg_nord))

    assert_select "a[href='#{topic_path(topic: 'gruen', district: districts(:hamburg_nord))}']"
    assert_select "a[href='#{topic_path(topic: 'kultur', district: districts(:hamburg_nord))}']", count: 0
  end

  test 'GET show serves no other format' do
    get "/#{districts(:hamburg_nord).to_param}/themen/strassenverkehr.rss"

    assert_response :not_found
  end
end
