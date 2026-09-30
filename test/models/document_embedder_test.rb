# frozen_string_literal: true

require 'test_helper'

class DocumentEmbedderTest < ActiveSupport::TestCase
  # Stands in for the model: a vector made from the text's length, and the
  # inputs it was given.
  class FakePipeline
    attr_reader :inputs

    def initialize
      @inputs = []
    end

    def call(texts)
      @inputs.concat(texts)
      texts.map { |text| Array.new(768) { |i| i.zero? ? text.length.to_f : 0.0 } }
    end
  end

  setup do
    @pipeline = FakePipeline.new
    @embedder = DocumentEmbedder.new(@pipeline)
    @document = documents(:document_7)
  end

  test 'embeds the title and the start of the full text with the e5 prefix' do
    @document.full_text = 'x' * 3000

    @embedder.embed(@document)

    assert_equal "passage: #{@document.title}\n#{'x' * 2000}", @pipeline.inputs.sole
  end

  test 'stores one embedding per document, replaced on update' do
    @embedder.update(@document)
    @document.update!(full_text: 'Ein anderer Text')
    @embedder.update(@document)

    embedding = DocumentEmbedding.find_by!(document: @document)

    assert_equal DocumentEmbedder::NAME, embedding.model
    assert_equal DocumentEmbedder.digest(@document), embedding.digest
    assert_equal DocumentEmbedder.text(@document).length + 'passage: '.length, embedding.embedding.first
  end

  test 'a document is outdated until embedded, and again when its text changes' do
    assert_includes DocumentEmbedder.outdated, @document

    @embedder.update(@document)

    assert_not_includes DocumentEmbedder.outdated, @document

    @document.update!(title: "#{@document.title} (geändert)")

    assert_includes DocumentEmbedder.outdated, @document
  end

  test 'the digest in SQL matches the one in Ruby, umlauts and long texts included' do
    @document.update!(title: 'Grünfläche am Überseering', full_text: "Straße\n#{'ä' * 2500}")
    @embedder.update(@document)

    assert_not_includes DocumentEmbedder.outdated, @document
  end

  test 'a document without full text is embedded from its title' do
    @document.update!(full_text: nil)
    @embedder.update(@document)

    assert_not_includes DocumentEmbedder.outdated, @document
  end

  test 'an embedding of another model is outdated' do
    @embedder.update(@document)
    @document.embedding.update!(model: 'other-model')

    assert_includes DocumentEmbedder.outdated, @document
  end

  test 'documents without a title are never embedded' do
    @document.update_columns(title: nil) # rubocop:disable Rails/SkipsModelValidations

    assert_not_includes DocumentEmbedder.outdated, @document
  end
end
