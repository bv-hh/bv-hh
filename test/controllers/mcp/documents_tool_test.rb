# frozen_string_literal: true

require 'test_helper'

class Mcp::DocumentsToolTest < ActiveSupport::TestCase
  test 'call finds a document by its id' do
    document = documents(:document_7)

    result = Mcp::DocumentsTool.call(identifier: document.id.to_s).structured_content

    assert_equal document.number, result[:number]
  end

  test 'call finds a document by its number within a district' do
    result = Mcp::DocumentsTool.call(identifier: '21-4776', district: 'hamburg-nord').structured_content

    assert_equal '21-4776', result[:number]
  end

  test 'call lists similar documents' do
    document = documents(:document_7)
    similar = Document.create!(district: document.district, number: '21-9999', title: 'Ähnlich', allris_id: 1)
    vector = Array.new(768, 0.0).tap { |v| v[0] = 1.0 }
    [document, similar].each { |d| DocumentEmbedding.create!(document: d, model: DocumentEmbedder::NAME, digest: 'x', embedding: vector) }

    result = Mcp::DocumentsTool.call(identifier: document.id.to_s).structured_content

    assert_equal [{ id: similar.id, number: '21-9999', title: 'Ähnlich', district: 'Hamburg-Nord' }], result[:similar_documents]
  end

  test 'call lists the documents it names and those naming it' do
    document = documents(:document_7)
    referenced = documents(:document_227)
    document.update!(full_text: "Siehe Drs. #{referenced.number}")
    citing = Document.create!(district: document.district, number: '21-9998', title: 'Nennt', allris_id: 2,
                              full_text: "Bezug: Drs. #{document.number}")

    result = Mcp::DocumentsTool.call(identifier: document.id.to_s).structured_content

    assert_equal [{ id: referenced.id, number: referenced.number, title: referenced.title }], result[:referenced_documents]
    assert_equal [{ id: citing.id, number: '21-9998', title: 'Nennt' }], result[:citing_documents]
  end

  test 'call returns an error for an unknown district' do
    result = Mcp::DocumentsTool.call(identifier: '21-4776', district: 'atlantis').structured_content

    assert result.dig(:error, :message).present?
  end

  test 'call returns an error when no document matches' do
    result = Mcp::DocumentsTool.call(identifier: '999999999').structured_content

    assert result.dig(:error, :message).present?
  end
end
