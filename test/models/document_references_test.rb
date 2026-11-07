# frozen_string_literal: true

require 'test_helper'

class DocumentReferencesTest < ActiveSupport::TestCase
  setup do
    @document = documents(:document_7) # 21-4776, Hamburg-Nord
  end

  test 'finds Drucksache numbers in their written forms, each once' do
    text = 'Siehe Drs. 21-4512 und Drucksache 21–4728.1 (vgl. Drs. 21-4512); Harburg schrieb XIX-4929.1.'

    assert_equal %w[21-4512 21-4728.1 XIX-4929.1], Document.references_in(text, '21-4776')
  end

  test 'leaves out Bürgerschaft numbers, dates, amounts and longer numbers' do
    text = 'Bürgerschaftsdrucksache 22/1234, am 2021-10-04, 3,10-5,00 EUR, Senats-Drs. 21-12345, Seite 22-123'

    assert_empty Document.references_in(text, '21-4776')
  end

  test "leaves out the document's own family" do
    text = 'Zur Drs. 21-4776, ergänzt durch 21-4776.1 und 21-4776.1.2, siehe auch 21-4777'

    assert_equal %w[21-4777], Document.references_in(text, '21-4776.1')
  end

  test 'extracts the references whenever the text changes' do
    @document.update!(full_text: 'Bezug: Drs. 21-4512')

    assert_equal %w[21-4512], @document.referenced_numbers

    @document.update!(full_text: 'Kein Bezug mehr')

    assert_empty @document.referenced_numbers
  end

  test 'links both ways within the Bezirk, by the exact number' do
    referenced = documents(:document_227) # 21-4512
    @document.update!(full_text: 'Siehe Drs. 21-4512, Drs. 21-4512.1 und Drs. 21-9999')

    assert_equal [referenced], @document.referenced_documents.to_a
    assert_equal [@document], referenced.citing_documents.to_a
  end

  test 'does not link a document of another Bezirk with the same number' do
    altona = District.create!(name: 'Altona', allris_base_url: 'https://sitzungsdienst-altona.hamburg.de', order: 2)
    elsewhere = Document.create!(district: altona, number: '21-4512', title: 'Anderswo', allris_id: 1)
    @document.update!(full_text: 'Siehe Drs. 21-4512')

    assert_not_includes @document.referenced_documents, elsewhere
    assert_empty elsewhere.citing_documents
  end

  test 'extracts again when the number changes, as the own family moves with it' do
    @document.update!(full_text: 'Siehe Drs. 21-4512 und 21-4776.1')

    assert_equal %w[21-4512], @document.referenced_numbers

    @document.update!(number: '21-4512')

    assert_equal %w[21-4776.1], @document.referenced_numbers
  end

  test 'links list what names it newest first' do
    older = Document.create!(district: @document.district, number: '21-4800', title: 'Älter', allris_id: 1, full_text: 'Drs. 21-4776')
    newer = Document.create!(district: @document.district, number: '21-4900', title: 'Neuer', allris_id: 2, full_text: 'Drs. 21-4776')

    assert_equal [newer, older], @document.links[:citing].to_a
  end
end
