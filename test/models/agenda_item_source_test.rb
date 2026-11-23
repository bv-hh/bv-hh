# frozen_string_literal: true

require 'test_helper'

# AgendaItem#source_from against a stand-in for Net::HTTP, so no request
# leaves the test.
class AgendaItemSourceTest < ActiveSupport::TestCase
  Response = Struct.new(:body, :headers) do
    delegate :[], to: :headers
  end

  # Answers each path with the next response queued for it, and records what
  # was asked with which headers.
  class FakeHttp
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def get(path, headers = {})
      @requests << [path, headers]
      @responses.fetch(path).shift
    end
  end

  ITEM_PATH = '/bi/to020.asp?TOLFDNR=1064444'
  MEETING_PATH = '/bi/to010.asp?SILFDNR=1003452'
  REDIRECT = '<head><title>Object moved</title></head><body>This object may be found <a HREF="noauth.asp">here</a>.</body>'
  PAGE = '<table class="risdeco"><tr><td class="text3">ungeändert beschlossen</td></tr></table>'

  setup do
    meeting = Meeting.create!(district: districts(:hamburg_nord), title: 'Sitzung', date: Date.new(2025, 3, 24), allris_id: 1_003_452)
    @item = AgendaItem.new(meeting:, allris_id: 1_064_444)
  end

  test 'returns the page when ALLRIS serves it' do
    http = FakeHttp.new(ITEM_PATH => [Response.new(PAGE, {})])

    assert_equal PAGE, @item.source_from(http, ITEM_PATH)
    assert_equal 1, http.requests.size
  end

  test 'after a redirect to noauth.asp, opens the meeting for a session and asks once more with it' do
    http = FakeHttp.new(
      ITEM_PATH => [Response.new(REDIRECT, {}), Response.new(PAGE, {})],
      MEETING_PATH => [Response.new('<html>Tagesordnung</html>', { 'set-cookie' => 'ASPSESSIONIDSAACTDDQ=FJLB; path=/' })]
    )

    assert_equal PAGE, @item.source_from(http, ITEM_PATH)
    assert_equal [ITEM_PATH, MEETING_PATH, ITEM_PATH], http.requests.map(&:first)
    assert_equal({ 'Cookie' => 'ASPSESSIONIDSAACTDDQ=FJLB' }, http.requests.last.last)
  end

  test 'keeps the redirect when the meeting sets no session' do
    http = FakeHttp.new(ITEM_PATH => [Response.new(REDIRECT, {})], MEETING_PATH => [Response.new('', {})])

    assert_equal REDIRECT, @item.source_from(http, ITEM_PATH)
    assert_equal 2, http.requests.size
  end
end
