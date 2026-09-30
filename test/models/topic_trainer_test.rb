# frozen_string_literal: true

require 'test_helper'

class TopicTrainerTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @random = Random.new(1)
  end

  # Documents about sport lie around one point, those about culture around
  # another, with noise on a few dimensions; the rules tagged them.
  def document(topics, center, classified: [])
    number = Document.unscoped.count + 1
    document = @district.documents.create!(allris_id: 90_000 + number, title: "Drucksache #{number}", number: "99-#{number}")
    document.update_columns(topics:, classified_topics: classified, topics_version: Topic::VERSION) # rubocop:disable Rails/SkipsModelValidations
    vector = Array.new(768) { |i| (i == center ? 1.0 : 0.0) + (i < 8 ? @random.rand * 0.2 : 0.0) }
    DocumentEmbedding.create!(document:, model: DocumentEmbedder::NAME, digest: 'x', embedding: vector)
    document
  end

  test 'learns to recognise a topic from the documents the rules tag' do
    40.times { document(%w[sport], 0) }
    40.times { document(%w[kultur], 1) }

    TopicTrainer.new(exclude: []).train!

    sport = TopicModel.find_by!(topic: 'sport')
    unseen = document(%w[kultur], 0) # a sport document the rules got wrong

    assert_includes TopicModel.predict(unseen), 'sport'
    assert_operator sport.metrics['recall'], :>, 0.9
    assert_equal 40, sport.metrics['positives']
  end

  test 'documents the rules tag with nothing and gold documents are not learned from' do
    40.times { document(%w[sport], 0) }
    40.times { document(%w[kultur], 1) }
    untagged = document([], 0)
    gold = document(%w[kultur], 0)

    TopicTrainer.new(exclude: [gold.id]).train!

    assert_equal 80, TopicModel.find_by!(topic: 'sport').metrics['documents']
    assert_includes TopicModel.predict(untagged), 'sport'
  end

  test 'what the classifier added before is not a label' do
    40.times { document(%w[sport], 0) }
    40.times { document(%w[kultur], 1) }
    document(%w[kultur sport], 1, classified: %w[sport])

    TopicTrainer.new(exclude: []).train!

    assert_equal 40, TopicModel.find_by!(topic: 'sport').metrics['positives']
  end

  test 'replaces the models of an earlier training' do
    40.times { document(%w[sport], 0) }
    40.times { document(%w[kultur], 1) }

    2.times { TopicTrainer.new(exclude: []).train! }

    assert_equal Topic.count, TopicModel.count
  end
end
