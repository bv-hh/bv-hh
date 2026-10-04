# frozen_string_literal: true

# Raises a topic's classifier threshold until what the classifier adds is
# right often enough, judged by the calibration gold set
# (db/gold/topics_calibration.jsonl): random documents labelled by hand, none of
# them trained on.
#
# TopicTrainer first picks a threshold against the rules (weak labels). That
# says nothing about the documents the classifier exists for: those the rules
# don't tag. Here only those count. Of the calibration documents the rules
# don't tag with the topic but the classifier would, sorted by score, the
# threshold keeps the most whose share of right ones is still PRECISION. If
# not even the best-scored addition is right, the topic gets no classifier.
#
# The threshold only ever goes up, so a calibration set too small to judge a
# topic leaves the rules' threshold as it is.
#
# A topic is judged on the random documents plus those drawn as its own
# additions (stratum added:<topic>), not on another topic's additions: those
# were drawn by a different classifier and would skew the share.
class TopicCalibration
  PRECISION = 0.8

  Sample = Struct.new(:embedding, :rules, :gold, :stratum, keyword_init: true)

  attr_reader :samples

  def self.load(path = TopicGoldSet::CALIBRATION_PATH)
    set = TopicGoldSet.load(path)
    found = set.documents(set.labelled)
    embeddings = DocumentEmbedding.where(model: DocumentEmbedder::NAME, document_id: found.values.map(&:id))
                                  .pluck(:document_id, :embedding).to_h
    new(found.filter_map do |entry, document|
      embedding = embeddings[document.id] or next
      Sample.new(embedding:, rules: document.topics - document.classified_topics, gold: entry.topics, stratum: entry.stratum)
    end)
  end

  def initialize(samples)
    @samples = samples
  end

  # [threshold, metrics] for the topic key, its raw weights and bias, starting
  # from threshold.
  def threshold(key, weights, bias, threshold)
    added = additions(key, weights, bias, threshold)
    return [threshold, { added: 0 }] if added.empty?

    kept = kept_count(added.map(&:last))
    metrics = { added: added.size, right: added.count(&:last), kept:, kept_right: added.first(kept).count(&:last) }
    [raised(threshold, added.map(&:first), kept), metrics]
  end

  private

  # [score, right?] of the samples the classifier adds to the rules for key at
  # threshold, best first.
  def additions(key, weights, bias, threshold)
    samples.select { |sample| [nil, 'random', "added:#{key}"].include?(sample.stratum) }
           .reject { |sample| sample.rules.include?(key) }
           .map { |sample| [score(sample, weights, bias), sample.gold.include?(key)] }
           .select { |score, _right| score >= threshold }
           .sort_by { |score, _right| -score }
  end

  def score(sample, weights, bias)
    sample.embedding.each_with_index.sum { |value, index| value * weights[index] } + bias
  end

  # How many of the additions, best first, to keep: the most whose share of
  # right ones is at least PRECISION, 0 when there is none.
  def kept_count(rights)
    right = 0
    rights.each_with_index.reduce(0) do |kept, (is_right, index)|
      right += 1 if is_right
      right >= PRECISION * (index + 1) ? index + 1 : kept
    end
  end

  # Halfway between the last addition kept and the next one; above every one
  # when none is kept.
  def raised(threshold, scores, kept)
    return threshold if kept == scores.size
    return Float::INFINITY if kept.zero?

    (scores[kept - 1] + scores[kept]) / 2
  end
end
