# frozen_string_literal: true

require 'test_helper'

class TopicCalibrationTest < ActiveSupport::TestCase
  # A one-dimensional embedding is enough: with weight 1 and bias 0 the score
  # is the embedding itself.
  def sample(score, gold: [], rules: [])
    TopicCalibration::Sample.new(embedding: [score], rules:, gold:)
  end

  def threshold(samples, from: 0.0)
    TopicCalibration.new(samples).threshold('sport', [1.0], 0.0, from)
  end

  test 'keeps the additions as long as enough of them are right' do
    samples = [sample(9.0, gold: %w[sport]), sample(8.0, gold: %w[sport]), sample(7.0, gold: %w[sport]),
               sample(6.0, gold: %w[sport]), sample(5.0), sample(4.0), sample(3.0)]

    threshold, metrics = threshold(samples)

    assert_in_delta 5.5, threshold # 4 of 4 right; 4 of 5 is below PRECISION
    assert_equal({ added: 7, right: 4, kept: 4, kept_right: 4 }, metrics)
  end

  test 'gives the topic no classifier when not even the best addition is right' do
    threshold, = threshold([sample(9.0), sample(8.0, gold: %w[sport])])

    assert_equal Float::INFINITY, threshold
  end

  test 'only documents the rules do not tag count, and only above the threshold' do
    samples = [sample(9.0, rules: %w[sport]), sample(8.0, gold: %w[sport]), sample(-1.0)]

    threshold, metrics = threshold(samples)

    assert_in_delta 0.0, threshold
    assert_equal 1, metrics[:added]
  end

  test 'leaves the threshold alone without additions' do
    assert_equal [2.0, { added: 0 }], threshold([sample(1.0)], from: 2.0)
  end

  test 'judges a topic on random documents and its own additions only' do
    samples = [TopicCalibration::Sample.new(embedding: [9.0], rules: [], gold: [], stratum: 'added:kultur'),
               TopicCalibration::Sample.new(embedding: [8.0], rules: [], gold: %w[sport], stratum: 'added:sport'),
               TopicCalibration::Sample.new(embedding: [7.0], rules: [], gold: %w[sport], stratum: 'random')]

    threshold, metrics = threshold(samples)

    assert_in_delta 0.0, threshold
    assert_equal 2, metrics[:added]
  end
end
