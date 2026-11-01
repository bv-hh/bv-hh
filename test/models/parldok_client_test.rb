# frozen_string_literal: true

require 'test_helper'

class ParldokClientTest < ActiveSupport::TestCase
  setup do
    @search = ParldokClient.decode(file_fixture('parldok/search.json').read)
    @vorgang = ParldokClient.decode(file_fixture('parldok/vorgang.json').read)
  end

  test 'decode unwraps the JSON ParlDok sends as a string' do
    assert_equal 3, @search['count']
    assert_kind_of Array, @search['docs']
  end

  test 'decode raises on an answer without success' do
    error = assert_raises(ParldokClient::Error) do
      ParldokClient.decode({ success: false, message: 'Sitzung abgelaufen', data: nil }.to_json)
    end
    assert_equal 'Sitzung abgelaufen', error.message
  end

  test 'parse_hits reads a Drucksache with its Vorgang' do
    hit = ParldokClient.parse_hits(@search).find { |h| h.parldok_id == 105_734 }

    assert_equal 23, hit.period
    assert_equal 5818, hit.number
    assert_equal 'Ausschussbericht', hit.kind
    assert_equal Date.new(2026, 10, 29), hit.date
    assert_equal 89_066, hit.process_id
    assert hit.drucksache
  end

  test 'parse_hits leaves the Vorgang empty for a Drucksache without one' do
    hit = ParldokClient.parse_hits(@search).find { |h| h.kind == 'Schriftliche Kleine Anfrage' }

    assert_nil hit.process_id
  end

  test 'parse_vorgang reads where the Vorgang stands and its Drucksachen' do
    vorgang = ParldokClient.parse_vorgang(@vorgang)

    assert_equal 89_066, vorgang.id
    assert_equal '23/5356', "#{vorgang.period}/#{vorgang.number}"
    assert_equal 'Überweisung im Vorwege gem. § 53 Abs. 1 GO an', vorgang.state
    assert_equal [105_244, 105_734], vorgang.hits.map(&:parldok_id)
    assert_equal %w[Antrag Ausschussbericht], vorgang.hits.map(&:kind)
  end

  test 'parse_vorgang keeps steps without a document, without the html marker' do
    steps = ParldokClient.parse_vorgang(@vorgang).steps

    assert_equal 3, steps.size
    assert_equal({ 'date' => '2026-09-15', 'text' => 'Antrag Senat', 'comment' => nil, 'parldok_id' => 105_244 },
                 steps.first)
    assert_nil steps.second['parldok_id']
    assert_equal 'am 29.09.2026', steps.second['comment']
  end

  test 'parse_vorgang is nil for a Drucksache without a Vorgang' do
    data = { 'id' => 0, 'process' => { 'id' => 0, 'positions' => [] } }

    assert_nil ParldokClient.parse_vorgang(data)
  end

  test 'each_page fetches the pages after the first by query id' do
    client = ParldokClient.new(delay: 0)
    first = @search.merge('count' => 250, 'queryid' => 42)
    requests = []
    client.define_singleton_method(:post) do |path, params|
      requests << [path, params]
      path == 'Fulltext/Search' ? first : { 'docs' => [] }
    end

    pages = []
    client.each_page(23) { |hits| pages << hits }

    assert_equal 3, pages.size
    assert_equal 3, pages.first.size
    assert_equal %w[Fulltext/Search Fulltext/Resultpage Fulltext/Resultpage], requests.map(&:first)
    assert_equal([100, 200], requests.drop(1).map { |_, params| params[:limit][:Start] })
    assert(requests.drop(1).all? { |_, params| params[:queryid] == 42 })
  end
end
