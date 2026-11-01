# frozen_string_literal: true

require 'test_helper'

class ProceedingImporterTest < ActiveSupport::TestCase
  # Answers from the captured search and Vorgang, and a text for every PDF
  # but those in no_text.
  class FakeClient
    attr_reader :texts_fetched, :vorgaenge_fetched
    attr_accessor :pages, :vorgang_answer, :no_text, :failing

    def initialize(pages:, vorgang:)
      @pages = pages
      @vorgang_answer = vorgang
      @no_text = []
      @failing = []
      @texts_fetched = []
      @vorgaenge_fetched = []
    end

    def each_page(_period, &)
      pages.each(&)
    end

    def vorgang(parldok_id)
      raise ParldokClient::Error, 'HTTP 500' if failing.include?(parldok_id)

      @vorgaenge_fetched << parldok_id
      vorgang_answer
    end

    def text(parldok_id)
      @texts_fetched << parldok_id
      "Text von #{parldok_id}" unless no_text.include?(parldok_id)
    end
  end

  setup do
    @hits = ParldokClient.parse_hits(ParldokClient.decode(file_fixture('parldok/search.json').read))
    @vorgang = ParldokClient.parse_vorgang(ParldokClient.decode(file_fixture('parldok/vorgang.json').read))
    @client = FakeClient.new(pages: [@hits], vorgang: @vorgang)
    @importer = ProceedingImporter.new(@client)
  end

  test 'a Drucksache without a Vorgang is a proceeding of its own' do
    @importer.import!

    paper = ProceedingPaper.find_by!(parldok_id: 105_714)
    proceeding = paper.proceeding
    assert_equal 'Schriftliche Kleine Anfrage', paper.kind
    assert_equal '23/5787', proceeding.designation
    assert_nil proceeding.parldok_process_id
    assert_equal [paper], proceeding.papers.to_a
    assert_equal paper.parldok_url, proceeding.parldok_url
  end

  test 'a Drucksache of a Vorgang brings the whole Vorgang' do
    @importer.import!

    proceeding = Proceeding.find_by!(parldok_process_id: 89_066)
    assert_equal '23/5356', proceeding.designation
    assert_equal 'Überweisung im Vorwege gem. § 53 Abs. 1 GO an', proceeding.state
    assert_equal [105_244, 105_734], proceeding.papers.map(&:parldok_id)
    assert_equal Date.new(2026, 10, 29), proceeding.date
    assert_equal 3, proceeding.steps.size
    assert_equal 'https://www.buergerschaft-hh.de/parldok/vorgang/89066', proceeding.parldok_url
  end

  test 'counts the Drucksachen and fetches their text' do
    assert_equal 4, @importer.import!

    proceeding = Proceeding.find_by!(parldok_process_id: 89_066)
    assert_equal "Text von 105244\n\nText von 105734", proceeding.full_text
    assert_equal 4, ProceedingPaper.where.not(full_text: nil).count
  end

  test 'a second run imports nothing and fetches nothing' do
    @importer.import!
    @client.texts_fetched.clear

    assert_equal 0, @importer.import!
    assert_empty @client.texts_fetched
  end

  test 'a PDF ParlDok does not have yet is tried again on the next run' do
    @client.no_text = [105_743]
    @importer.import!
    assert_nil ProceedingPaper.find_by!(parldok_id: 105_743).full_text

    @client.no_text = []
    @importer.import!
    assert_equal 'Text von 105743', ProceedingPaper.find_by!(parldok_id: 105_743).full_text
  end

  test 'types that are not about a place are skipped' do
    election = @hits.first.with(parldok_id: 1, number: 1, kind: 'Wahlvorschlag (Drucksache)', process_id: nil)
    @client.pages = [[election]]

    assert_equal 0, @importer.import!
    assert_not ProceedingPaper.exists?(parldok_id: 1)
  end

  test 'an Antrag imported alone moves into its Vorgang once there is one' do
    antrag = @vorgang.hits.first.with(process_id: nil)
    @client.pages = [[antrag]]
    @importer.import!
    alone = ProceedingPaper.find_by!(parldok_id: 105_244).proceeding
    assert_nil alone.parldok_process_id

    @client.pages = [[@hits.find { |hit| hit.parldok_id == 105_734 }]]
    @importer.import!

    paper = ProceedingPaper.find_by!(parldok_id: 105_244)
    assert_equal 89_066, paper.proceeding.parldok_process_id
    assert_not Proceeding.exists?(alone.id)
    assert_includes paper.proceeding.full_text, 'Text von 105244'
  end

  test 'an Antrag imported alone joins its Vorgang when its own hit shows one' do
    antrag = @vorgang.hits.first
    @client.pages = [[antrag.with(process_id: nil)]]
    @importer.import!

    @client.pages = [[antrag]]
    @importer.import!

    assert_equal 89_066, ProceedingPaper.find_by!(parldok_id: 105_244).proceeding.parldok_process_id
    assert_equal 1, Proceeding.count
  end

  test 'a Drucksache ParlDok fails on is skipped and the rest imported' do
    @client.failing = [105_734]

    assert_equal 2, @importer.import!
    assert_not ProceedingPaper.exists?(parldok_id: 105_734)
    assert ProceedingPaper.exists?(parldok_id: 105_714)
  end

  test 'periods before the previous one are not imported' do
    assert_raises(ArgumentError) { @importer.import!(21) }
  end

  test 'a closed period is imported but not refreshed' do
    @importer.import!
    Proceeding.update_all(period: 22, checked_at: 8.days.ago)
    @client.pages = []
    @client.vorgaenge_fetched.clear

    @importer.import!(22)

    assert_empty @client.vorgaenge_fetched
  end

  test 'nothing is asked for after the deadline' do
    assert_equal 0, @importer.import!(deadline: 1.minute.ago)
    assert_empty @client.texts_fetched
    assert_equal 0, Proceeding.count
  end

  test 'an open Vorgang not checked for a week is asked for again' do
    @importer.import!
    proceeding = Proceeding.find_by!(parldok_process_id: 89_066)
    proceeding.update!(checked_at: 8.days.ago)
    @client.pages = []
    @client.vorgaenge_fetched.clear
    @client.vorgang_answer = @vorgang.with(state: 'Annahme')

    @importer.import!

    assert_equal [105_244], @client.vorgaenge_fetched
    assert_equal 'Annahme', proceeding.reload.state
    assert_in_delta Time.current, proceeding.checked_at, 1.minute
  end

  test 'a Vorgang checked recently or settled is not asked for again' do
    @importer.import!
    proceeding = Proceeding.find_by!(parldok_process_id: 89_066)
    @client.pages = []
    @client.vorgaenge_fetched.clear

    @importer.import!
    proceeding.update!(checked_at: 8.days.ago, state: 'Ablehnung')
    @importer.import!

    assert_empty @client.vorgaenge_fetched
  end

  test 'a refresh brings the Drucksachen added to the Vorgang' do
    @importer.import!
    Proceeding.find_by!(parldok_process_id: 89_066).update!(checked_at: 8.days.ago)
    report = @vorgang.hits.last.with(parldok_id: 105_900, number: 5900, kind: 'Bericht')
    @client.pages = []
    @client.vorgang_answer = @vorgang.with(hits: @vorgang.hits + [report])

    assert_equal 1, @importer.import!
    assert_equal 'Text von 105900', ProceedingPaper.find_by!(parldok_id: 105_900).full_text
  end
end
