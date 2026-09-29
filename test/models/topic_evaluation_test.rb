# frozen_string_literal: true

require 'test_helper'

class TopicEvaluationTest < ActiveSupport::TestCase
  def entry(number, stratum, topics)
    TopicGoldSet::Entry.new(district: 'hamburg-nord', number:, stratum:, topics:, labeler: 'claude')
  end

  test 'counts hits, wrong and missing tags per topic, and recall on the random stratum' do
    set = TopicGoldSet.new([
                             entry('21-4776', 'random', %w[strassenverkehr radverkehr]),
                             entry('21-4512', 'topic', %w[kultur]),
                             entry('21-4777', 'random', %w[gruen]),
                             entry('0-0', 'random', %w[sport]),
                           ])
    tagger = { '21-4776' => %w[strassenverkehr], '21-4512' => %w[kultur haushalt], '21-4777' => [] }
    evaluation = TopicEvaluation.new(set, tagger: ->(document) { tagger.fetch(document.number) }).run

    assert_equal 3, evaluation.evaluated
    assert_equal 1, evaluation.missing
    assert_equal [1, 0, 0], evaluation.scores['strassenverkehr'].to_h.values_at(:tp, :fp, :fn)
    assert_equal [0, 0, 1], evaluation.scores['radverkehr'].to_h.values_at(:tp, :fp, :fn)
    assert_equal [0, 1, 0], evaluation.scores['haushalt'].to_h.values_at(:tp, :fp, :fn)
    assert_in_delta 2.0 / 3, evaluation.total.precision
    assert_in_delta 0.5, evaluation.total.recall
    assert_in_delta 1.0 / 3, evaluation.total.random_recall
    assert_equal 1, evaluation.random_untagged, 'document_4 has gold topics and no tags'
    assert_equal %i[false_negative false_positive false_negative], evaluation.misses.map(&:kind)
  end

  test 'a topic without cases has no ratios' do
    evaluation = TopicEvaluation.new(TopicGoldSet.new([]), tagger: ->(_document) { [] }).run

    assert_nil evaluation.scores['sport'].precision
    assert_nil evaluation.total.f1
  end
end
