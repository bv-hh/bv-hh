# frozen_string_literal: true

require 'net/http'

# Reads the Bürgerschaft's Parlamentsdatenbank (ParlDok). There is no published
# API: these are the JSON endpoints ParlDok's own front end calls, found in
# /parldok/js/bundle.js, so they can change without notice. Each answers
# {"success": true, "data": "<the JSON as a string>"}. Fetching and parsing are
# separate so the parsers can be tested against captured answers.
#
# Requests go out one at a time, DELAY apart. ParlDok stops answering
# altogether — every request, the RSS feed included — after a few dozen in
# quick succession.
class ParldokClient
  BASE_URL = 'https://www.buergerschaft-hh.de/parldok'
  DELAY = 5
  # The most one page of hits holds; a larger Length is cut to it.
  PAGE_SIZE = 100
  # The filter types of a search tag, pd.facet_* in the bundle, and the value
  # of the document kind filter for Drucksachen (Fulltext/Filter lists them).
  PERIOD_FACET = 10
  KIND_FACET = 7
  DRUCKSACHE = '1'
  # ParlDok sorts by date, newest first, with this.
  SORT_BY_DATE = 2
  # The front end sends a random key it keeps per browser. ParlDok wants one,
  # not a particular one.
  DEVICE_KEY = 'bv-hh'
  HEADERS = {
    'User-Agent' => 'BV-HH (https://bv-hh.de)',
    'X-Requested-With' => 'XMLHttpRequest',
  }.freeze

  class Error < StandardError; end

  # A document in a list of hits. kind is ParlDok's document type ("Antrag",
  # "Schriftliche Kleine Anfrage"); drucksache tells a Drucksache from a
  # Plenarprotokoll or Ausschussprotokoll, which a Vorgang lists as well.
  Hit = Data.define(:parldok_id, :period, :number, :kind, :title, :date, :process_id, :drucksache)
  # A Vorgang: its Drucksachen as hits, and every step with or without one.
  Vorgang = Data.define(:id, :period, :number, :title, :abstract, :state, :steps, :hits)

  def self.decode(body)
    envelope = JSON.parse(body)
    raise Error, envelope['message'].presence || 'no success' unless envelope['success']

    JSON.parse(envelope['data'])
  end

  def self.parse_hits(data)
    Array(data['docs']).map { |doc| hit(doc) }
  end

  # nil for a Drucksache that belongs to no Vorgang. ParlDok answers that with
  # a Vorgang of id 0 rather than with nothing.
  def self.parse_vorgang(data)
    process = data['process']
    return if process.blank? || process['id'].to_i.zero?

    positions = Array(process['positions'])
    Vorgang.new(
      id: process['id'],
      period: process['lp'],
      number: process['number'].to_i,
      title: process['title'],
      abstract: process['processabstract'].presence,
      state: process['state'].presence,
      steps: positions.map { |position| step(position) },
      hits: positions.filter_map { |position| hit(position['doc']) if position['doc'] }
    )
  end

  def self.hit(doc)
    Hit.new(
      parldok_id: doc['id'],
      period: doc['lp'],
      number: doc['number'].to_i,
      kind: doc['type'],
      title: doc['title'],
      date: date(doc['date']),
      process_id: (doc['processid'] if doc['hasProcess']),
      drucksache: doc['kind'] == 'Drucksache'
    )
  end

  # A step reads "html:Ausschussbericht Haushaltsausschuss" when it links a
  # document, plain text otherwise; the comment adds a date or a committee.
  def self.step(position)
    text = position['text'].to_s.delete_prefix('html:')
    {
      'date' => date(position['date'])&.iso8601,
      'text' => Nokogiri::HTML.fragment(text).text.squish,
      'comment' => position['comment'].to_s.delete_prefix(';').squish.presence,
      'parldok_id' => position.dig('doc', 'id'),
    }
  end

  def self.date(value)
    Date.strptime(value, '%d.%m.%Y') if value.present?
  end

  def self.document_url(parldok_id)
    "#{BASE_URL}/dokument/#{parldok_id}"
  end

  def self.vorgang_url(process_id)
    "#{BASE_URL}/vorgang/#{process_id}"
  end

  def initialize(delay: DELAY)
    @delay = delay
  end

  # Yields the Drucksachen of a period a page at a time, newest first. The
  # search answers the first page and a query id; the others are fetched by
  # that id.
  def each_page(period)
    data = post('Fulltext/Search', search_params(period))
    yield self.class.parse_hits(data)

    query_id = data['queryid']
    (PAGE_SIZE...data['count'].to_i).step(PAGE_SIZE) do |start|
      page = post('Fulltext/Resultpage', devicekey: DEVICE_KEY, queryid: query_id,
                                         limit: { Start: start, Length: PAGE_SIZE })
      yield self.class.parse_hits(page)
    end
  end

  def vorgang(parldok_id)
    self.class.parse_vorgang(post('Process/Document', devicekey: DEVICE_KEY, id: parldok_id, position: 0))
  end

  # The text of a Drucksache's PDF, or nil while ParlDok has none: it then
  # answers with an HTML page ("noch nicht verfügbar") instead.
  def text(parldok_id)
    response = request(Net::HTTP::Get.new(URI(self.class.document_url(parldok_id)), HEADERS))
    return unless response.content_type == 'application/pdf'

    SimpleTextExtract.extract(filename: "#{parldok_id}.pdf", raw: response.body)
  end

  private

  def search_params(period)
    {
      devicekey: DEVICE_KEY,
      sort: SORT_BY_DATE,
      limit: { Length: PAGE_SIZE },
      tags: [
        { type: PERIOD_FACET, id: period.to_s, label: period.to_s },
        { type: KIND_FACET, id: DRUCKSACHE, label: 'Drucksache', ored: true },
      ],
    }
  end

  def post(path, params)
    request = Net::HTTP::Post.new(URI("#{BASE_URL}/#{path}"), HEADERS)
    request.set_form_data(data: params.to_json)
    self.class.decode(request(request).body)
  end

  def request(request)
    pause
    uri = request.uri
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
      http.request(request)
    end
    raise Error, "#{uri}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response
  end

  def pause
    sleep(@delay) if @requested
    @requested = true
  end
end
