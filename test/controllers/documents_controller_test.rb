# frozen_string_literal: true

require 'test_helper'

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  # A test below adds a Bezirk, which District.lookup would keep after rollback.
  teardown { District.instance_variable_set(:@districts, nil) }

  test 'GET index' do
    get documents_path(district: districts.first)
    assert_response :success
  end

  test 'GET show' do
    documents.each do |document|
      get document_path(document.id)
      assert_redirected_to document_path(document, district: document.district)

      get document_path(document, district: document.district)
      assert_response :success
    end
  end

  test 'GET show leads from Hamburg through the Bezirk and its Drucksachen to the document' do
    document = documents(:document_7)
    district = document.district

    get document_path(document, district:)

    assert_select 'nav[aria-label=Brotkrumen] li', 4
    assert_select 'nav[aria-label=Brotkrumen] a[href=?]', root_with_district_path(district:), text: district.name
    assert_select 'nav[aria-label=Brotkrumen] a[href=?]', documents_path(district:), text: 'Drucksachen'
    assert_select 'nav[aria-label=Brotkrumen] li[aria-current=page]', text: document.number
    assert_select 'h1', count: 1
  end

  test 'GET show lists the topics of the document' do
    document = documents(:document_7)
    document.update_columns(topics: %w[spielplaetze unbekannt]) # rubocop:disable Rails/SkipsModelValidations

    get document_path(document, district: document.district)

    assert_select '.card-header', text: /Themen/
    assert_select "a.rounded-pill[href='#{topic_path(topic: 'spielplaetze', district: document.district)}']", text: 'Spielplätze'
  end

  test 'GET show lists similar Drucksachen with the Bezirk of those from elsewhere' do
    document = documents(:document_7)
    altona = District.create!(name: 'Altona', allris_base_url: 'https://sitzungsdienst-altona.hamburg.de', order: 2)
    similar = Document.create!(district: altona, number: '22-0100', title: 'Spielplatz am Elbufer', allris_id: 1)
    vector = Array.new(768, 0.0).tap { |v| v[0] = 1.0 }
    [document, similar].each { |d| DocumentEmbedding.create!(document: d, model: DocumentEmbedder::NAME, digest: 'x', embedding: vector) }

    get document_path(document, district: document.district)

    assert_select '.card-header', text: /Ähnliche Drucksachen/
    assert_select '.list-group-item', text: /22-0100 · Altona/
    assert_select "a[href='#{document_path(similar, district: altona)}']", text: similar.title
  end

  test 'GET show lists the Drucksachen it names and those naming it, the rest of a long list behind a toggle' do
    document = documents(:document_7)
    referenced = documents(:document_227)
    document.update!(full_text: "Siehe Drs. #{referenced.number}")
    citing = Array.new(7) do |i|
      Document.create!(district: document.district, number: "21-50#{i}0", title: "Nennt #{document.number} (#{i})",
                       allris_id: 100 + i, full_text: "Bezug: Drs. #{document.number}")
    end

    get document_path(document, district: document.district)

    assert_select '.card', text: /Verweist auf/ do
      assert_select "a[href='#{document_path(referenced, district: document.district)}']"
    end
    assert_select '.card', text: /Erwähnt in/
    citing.each { |linked| assert_select "a[href='#{document_path(linked, district: document.district)}']" }
    assert_select '#related-citing.collapse .list-group-item', 2
    assert_select 'button[data-bs-target="#related-citing"]', text: '2 weitere'
  end

  test 'GET show says where it stands by the meeting that decided, not a later one that recorded nothing' do
    travel_to Time.zone.local(2026, 6, 15, 12)
    document = documents(:document_7)
    committee = committees(:rega_ewi)
    [[10.weeks.ago, 'ungeändert beschlossen'], [2.weeks.ago, nil]].each do |time, decision|
      meeting = Meeting.create!(committee:, district: committee.district, date: time.to_date, title: 'Sitzung', allris_id: rand(1_000_000))
      AgendaItem.create!(meeting:, document:, decision:, title: document.title)
    end

    get document_path(document, district: document.district)

    assert_select 'p', text: /Stand:\s+beschlossen\s+·\s+#{Regexp.escape(committee.name)}\s+·\s+#{I18n.l(10.weeks.ago.to_date)}/
  end

  test 'GET show names a decision on the latest day once, whichever item comes first' do
    document = documents(:document_7)
    committee = committees(:rega_ewi)
    meeting = Meeting.create!(committee:, district: committee.district, date: Date.new(2026, 5, 4), title: 'Sitzung', allris_id: 9_999_002)
    2.times { AgendaItem.create!(meeting:, document:, decision: 'ungeändert beschlossen', title: document.title) }

    get document_path(document, district: document.district)

    assert_select 'p', text: /Stand:/, count: 0
  end

  test 'GET show dates a compact row by its latest meeting, as it shows no decision' do
    document = documents(:document_7)
    committee = committees(:rega_ewi)
    citing = Document.create!(district: document.district, number: '21-9997', title: 'Nennt', allris_id: 9_997, full_text: 'Drs. 21-4776')
    [[Date.new(2026, 3, 2), 'ungeändert beschlossen'], [Date.new(2026, 5, 4), nil]].each_with_index do |(date, decision), index|
      meeting = Meeting.create!(committee:, district: committee.district, date:, title: 'Sitzung', allris_id: 9_999_010 + index)
      AgendaItem.create!(meeting:, document: citing, decision:, title: citing.title)
    end

    get document_path(document, district: document.district)

    assert_select '.list-group-item', text: /21-9997.*#{I18n.l(Date.new(2026, 5, 4))}/m
  end

  test 'GET allris redirects to the document' do
    document = documents(:document_7)
    get allris_documents_path(district: districts.first, allris_id: document.allris_id)
    assert_redirected_to document_path(document, district: document.district)
  end

  test 'GET allris without district redirects to root' do
    get allris_documents_path(allris_id: 1)
    assert_redirected_to root_path
  end

  test 'GET suggest returns json' do
    get suggest_documents_path(district: districts.first, q: 'Eingabe')
    assert_response :success
    assert_equal 'application/json', @response.media_type
    assert_kind_of Array, JSON.parse(@response.body)
  end
end
