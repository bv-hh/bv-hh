# frozen_string_literal: true

# Precision and recall of a topic tagger against the gold set (TopicGoldSet).
# The tagger is anything that answers #call(document) with topic keys; by
# default the current rules, run live, so a rule change can be measured
# before any reassignment.
#
# Precision is taken over the whole set: every document the tagger tags with a
# topic tells whether that tag was right, whichever stratum it came from.
# Recall is given twice. Over the random stratum it is an unbiased estimate but
# rests on few cases for rare topics; over the whole set it has more cases but
# leans high, because the topic stratum was drawn from what the rules already
# find.
#
# Read-only. Driven by `rake topics:evaluate`.
class TopicEvaluation
  Score = Struct.new(:tp, :fp, :fn, :random_tp, :random_fn, keyword_init: true) do
    def self.zero
      new(tp: 0, fp: 0, fn: 0, random_tp: 0, random_fn: 0)
    end

    # One document's contribution to one topic.
    def self.of(hit:, truth:, random:)
      tp = hit && truth ? 1 : 0
      fn = !hit && truth ? 1 : 0
      new(tp:, fp: hit && !truth ? 1 : 0, fn:, random_tp: random ? tp : 0, random_fn: random ? fn : 0)
    end

    def precision
      ratio(tp, tp + fp)
    end

    def recall
      ratio(tp, tp + fn)
    end

    def random_recall
      ratio(random_tp, random_tp + random_fn)
    end

    def f1
      return if precision.nil? || recall.nil? || (precision + recall).zero?

      2 * precision * recall / (precision + recall)
    end

    def add(other)
      Score.new(**to_h.merge(other.to_h) { |_key, mine, theirs| mine + theirs })
    end

    private

    def ratio(part, whole)
      whole.zero? ? nil : part.to_f / whole
    end
  end

  Miss = Struct.new(:topic, :kind, :entry, :document, keyword_init: true)

  RULES = ->(document) { TopicClassifier.new(document).topics }

  attr_reader :scores, :misses, :evaluated, :missing, :random_untagged

  def initialize(gold_set = TopicGoldSet.load, tagger: RULES)
    @gold_set = gold_set
    @tagger = tagger
  end

  def run
    @scores = Topic.keys.index_with { Score.zero }
    @misses = []
    @random_untagged = 0

    labelled = @gold_set.labelled
    documents = @gold_set.documents(labelled)
    @missing = labelled.size - documents.size
    @evaluated = documents.size

    documents.each { |entry, document| score(entry, document, @tagger.call(document).to_a & Topic.keys) }
    self
  end

  def total
    scores.values.reduce(Score.zero) { |sum, score| sum.add(score) }
  end

  private

  def score(entry, document, predicted)
    gold = entry.topics
    random = entry.stratum == 'random'
    @random_untagged += 1 if random && predicted.empty? && gold.any?

    Topic.each do |topic|
      hit = predicted.include?(topic.key)
      truth = gold.include?(topic.key)
      next unless hit || truth

      scores[topic.key] = scores[topic.key].add(Score.of(hit:, truth:, random:))
      @misses << Miss.new(topic:, kind: hit ? :false_positive : :false_negative, entry:, document:) if hit != truth
    end
  end
end
