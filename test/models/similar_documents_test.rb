# frozen_string_literal: true

require 'test_helper'

class SimilarDocumentsTest < ActiveSupport::TestCase
  setup do
    @document = documents(:document_7)
    @nord = @document.district
    @altona = District.create!(name: 'Altona', allris_base_url: 'https://sitzungsdienst-altona.hamburg.de', order: 2)
    embed(@document, 0.0)
  end

  test 'lists documents from any Bezirk closer than the limit, closest first' do
    near = new_document(@altona, '22-0100', 0.03)
    nearer = new_document(@altona, '22-0101', 0.01)
    new_document(@altona, '22-0102', SimilarDocuments::MAX_DISTANCE + 0.02)

    assert_equal [nearer, near], SimilarDocuments.new(@document).to_a
  end

  test "leaves out the document's own family and what is excluded" do
    family = [new_document(@nord, "#{@document.number}.1", 0.01), new_document(@nord, @document.number.split('.').first, 0.01)]
    excluded = new_document(@altona, '22-0100', 0.02)
    kept = new_document(@altona, '22-0101', 0.03)
    other_family = new_document(@altona, "#{@document.number}.1", 0.04)

    found = SimilarDocuments.new(@document, exclude: [excluded.id]).to_a

    assert_equal [kept, other_family], found
    assert_empty found & family
  end

  test 'keeps places for other Bezirke that the own one, closer, would fill' do
    own = Array.new(4) { |i| new_document(@nord, "21-90#{i}0", 0.01 + (i * 0.001)) }
    others = Array.new(4) { |i| new_document(@altona, "22-01#{i}0", 0.05 + (i * 0.001)) }

    assert_equal own.first(SimilarDocuments::SAME_DISTRICT) + others.first(SimilarDocuments::OTHER_DISTRICTS),
                 SimilarDocuments.new(@document).to_a
  end

  test 'takes the closest of another family only' do
    closest = new_document(@altona, '22-0100.1', 0.02)
    new_document(@altona, '22-0100', 0.03)
    new_document(@altona, '22-0100.2', 0.04)
    next_one = new_document(@altona, '22-0200', 0.05)

    assert_equal [closest, next_one], SimilarDocuments.new(@document).to_a
  end

  test 'counts documents without a number as families of their own' do
    first = new_document(@altona, nil, 0.02)
    second = new_document(@altona, nil, 0.03)

    assert_equal [first, second], SimilarDocuments.new(@document).to_a
  end

  test 'keeps the ids for a while and leaves out a document hidden since' do
    hidden = new_document(@altona, '22-0100', 0.02)
    kept = new_document(@altona, '22-0101', 0.03)
    cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    assert_equal [hidden, kept], SimilarDocuments.new(@document).to_a

    hidden.update!(non_public: true)
    new_document(@altona, '22-0102', 0.01)

    assert_equal [kept], SimilarDocuments.new(@document).to_a
  ensure
    Rails.cache = cache
  end

  test 'finds nothing for a document without an embedding of the current model' do
    new_document(@altona, '22-0100', 0.01)
    @document.embedding.update!(model: 'another-model')

    assert_empty SimilarDocuments.new(@document.reload).to_a
  end

  private

  def new_document(district, number, distance)
    document = Document.create!(district:, number:, title: "Drucksache #{number}", allris_id: rand(1_000_000))
    embed(document, distance)
    document
  end

  # A unit vector at the given cosine distance from the first axis.
  def embed(document, distance)
    tilt = Math.sqrt((1.0 / ((1 - distance)**2)) - 1)
    vector = Array.new(768, 0.0)
    vector[0] = 1.0
    vector[1] = tilt
    DocumentEmbedding.create!(document:, model: DocumentEmbedder::NAME, digest: 'test', embedding: vector)
  end
end
