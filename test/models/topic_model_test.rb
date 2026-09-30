# frozen_string_literal: true

require 'test_helper'

class TopicModelTest < ActiveSupport::TestCase
  setup do
    @document = documents(:document_7)
    @other = documents(:document_4)
  end

  # A vector pointing along dimension i.
  def axis(index, length = 1.0)
    Array.new(768) { |i| i == index ? length : 0.0 }
  end

  def embed(document, vector)
    DocumentEmbedding.create!(document:, model: DocumentEmbedder::NAME, digest: 'x', embedding: vector)
  end

  # A model for the topic that scores 10 * the embedding's value on
  # dimension index, tagging from 5 on.
  def model_for(topic, index)
    TopicModel.create!(topic:, model: DocumentEmbedder::NAME, weights: axis(index, 10.0), bias: 0.0, threshold: 5.0)
  end

  def set_topics(document, topics, classified = [])
    document.update_columns(topics:, classified_topics: classified) # rubocop:disable Rails/SkipsModelValidations
  end

  test 'predicts the topics whose score reaches the threshold, in the order of the config' do
    model_for('sport', 0)
    model_for('radverkehr', 1)
    model_for('kultur', 2)
    embed(@document, axis(0).zip(axis(1)).map { |a, b| (a + b) * 0.7 })

    assert_equal %w[radverkehr sport], TopicModel.predict(@document)
  end

  test 'predicts nothing without an embedding or for another model' do
    model_for('sport', 0)

    assert_empty TopicModel.predict(@document)

    embed(@document, axis(0))
    TopicModel.update_all(model: 'other')

    assert_empty TopicModel.predict(@document)
  end

  test 'classify_all! adds the topics the rules missed and keeps the rules' do
    model_for('sport', 0)
    model_for('radverkehr', 1)
    embed(@document, axis(0).zip(axis(1)).map { |a, b| (a + b) * 0.7 })
    set_topics(@document, %w[radverkehr kultur])

    assert_equal 1, TopicModel.classify_all!

    @document.reload

    assert_equal %w[radverkehr sport kultur], @document.topics
    assert_equal %w[sport], @document.classified_topics
  end

  test 'classify_all! takes back what an older model added, not what the rules found' do
    model_for('radverkehr', 1)
    embed(@document, axis(0))
    set_topics(@document, %w[sport kultur], %w[sport])

    TopicModel.classify_all!
    @document.reload

    assert_equal %w[kultur], @document.topics
    assert_empty @document.classified_topics
  end

  test 'classify_all! leaves documents alone that have nothing to change' do
    model_for('sport', 0)
    embed(@document, axis(0))
    set_topics(@document, %w[kultur sport], %w[sport])
    set_topics(@other, %w[kultur])

    assert_equal 0, TopicModel.classify_all!
    assert_equal %w[kultur], @other.reload.topics
  end

  test 'assign_topics! combines the rules with the classifier' do
    model_for('sport', 0)
    embed(@document, axis(0))

    @document.assign_topics!

    assert_includes @document.reload.topics, 'sport'
    assert_equal %w[sport], @document.classified_topics - TopicClassifier.new(@document).topics
  end
end
