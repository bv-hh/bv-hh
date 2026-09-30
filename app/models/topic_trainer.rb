# frozen_string_literal: true

# Trains a TopicModel per topic: a logistic regression on the document
# embeddings, with the rules' topics as labels ("weak labels": imperfect, but
# many). It learns what the documents the rules tag have in common beyond the
# terms, and then recognises documents that look like them.
#
# - Only documents the rules tag with some topic are used. A document they tag
#   with nothing is often a miss, the very kind the classifier is meant to
#   find; as an example of "not this topic" it would teach it to miss them.
# - The gold sets are left out, so `rake topics:evaluate` measures documents
#   the classifier has not seen.
# - Every fifth document is held back for validation. The threshold per topic
#   is the one with the best F1 there, against the weak labels.
#
# The embeddings are standardised per dimension for training, which lets
# gradient descent converge; the weights are converted back, so the stored
# model scores raw embeddings.
class TopicTrainer
  STEPS = 300
  LEARNING_RATE = 0.05
  L2 = 1e-3
  VALIDATION = 5 # every n-th document

  Result = Struct.new(:topic, :weights, :bias, :threshold, :metrics, keyword_init: true)

  def initialize(exclude: TopicTrainer.gold_document_ids)
    require 'numo/narray'
    @exclude = exclude
  end

  def self.gold_document_ids
    %w[tuning test].flat_map do |name|
      set = TopicGoldSet.load(TopicGoldSet.path_for(name))
      set.documents(set.entries).map { |_entry, document| document.id }
    end
  end

  # Trains every topic and stores the models. Returns the results.
  def train!
    load_data
    results = Topic.map { |topic| train(topic.key) }
    TopicModel.transaction do
      TopicModel.delete_all
      results.each do |result|
        TopicModel.create!(topic: result.topic, model: DocumentEmbedder::NAME, weights: result.weights,
                           bias: result.bias, threshold: result.threshold, metrics: result.metrics)
      end
    end
    results
  end

  def train(key)
    labels = Numo::SFloat.cast(@labels.map { |topics| topics.include?(key) ? 1 : 0 })
    train_rows = Numo::Bit.cast(@validation.map(&:!)).where
    validation_rows = Numo::Bit.cast(@validation).where

    weights, bias = fit(@x[train_rows, true], labels[train_rows])
    scores = @x[validation_rows, true].dot(weights) + bias
    threshold, metrics = best_threshold(scores.to_a, labels[validation_rows].to_a.map(&:positive?))

    # Back from standardised to raw embeddings: w·(x - mean)/std + b.
    raw = weights / @std
    Result.new(topic: key, weights: raw.to_a, bias: bias - raw.dot(@mean), threshold:,
               metrics: metrics.merge(positives: labels.sum.to_i, documents: labels.size))
  end

  private

  def documents
    DocumentEmbedding.where(model: DocumentEmbedder::NAME).joins(:document)
                     .where(documents: { topics_version: Topic::VERSION })
                     .where.not(document_id: @exclude)
                     .where("documents.topics <> '{}' AND NOT documents.classified_topics @> documents.topics")
  end

  def load_data
    rows = documents.pluck(:document_id, :embedding, Arel.sql('documents.topics'), Arel.sql('documents.classified_topics'))
    raise 'No embedded documents with topics to train on' if rows.empty?

    @x = Numo::SFloat.cast(rows.pluck(1))
    @labels = rows.map { |_id, _embedding, topics, classified| topics - classified }
    @validation = rows.map { |id, *| (id % VALIDATION).zero? }

    @mean = @x.mean(0)
    @std = @x.stddev(0) + 1e-6
    @x = (@x - @mean) / @std
  end

  # Gradient descent with Adam on the log loss. The parameters are the weights
  # with the bias as last element.
  def fit(features, labels)
    sample_weights = balanced(labels)
    optimizer = Adam.new(features.shape[1] + 1, LEARNING_RATE)
    parameters = Numo::SFloat.zeros(features.shape[1] + 1)
    STEPS.times { parameters -= optimizer.step(gradient(features, labels, sample_weights, parameters)) }
    [parameters[0...-1].dup, parameters[-1]]
  end

  # Positives weighted up to balance the classes: most topics are on a few
  # percent of the documents.
  def balanced(labels)
    positives = [labels.sum, 1].max
    (labels * ((labels.size - positives) / positives)) + (1 - labels)
  end

  def gradient(features, labels, sample_weights, parameters)
    weights = parameters[0...-1]
    probabilities = 1 / (1 + Numo::NMath.exp(-(features.dot(weights) + parameters[-1])))
    errors = (probabilities - labels) * sample_weights
    total = sample_weights.sum
    ((errors.dot(features) / total) + (L2 * weights)).concatenate([errors.sum / total])
  end

  # The update of each step, from the gradient: a running average of it, scaled
  # per parameter by the running size of its squares.
  class Adam
    BETA1 = 0.9
    BETA2 = 0.999

    def initialize(size, learning_rate)
      @learning_rate = learning_rate
      @mean = Numo::SFloat.zeros(size)
      @square = Numo::SFloat.zeros(size)
      @count = 0
    end

    def step(gradient)
      @count += 1
      @mean = (BETA1 * @mean) + ((1 - BETA1) * gradient)
      @square = (BETA2 * @square) + ((1 - BETA2) * (gradient**2))
      correction = Math.sqrt(1 - (BETA2**@count)) / (1 - (BETA1**@count))
      @learning_rate * correction * @mean / (Numo::NMath.sqrt(@square) + 1e-8)
    end
  end

  # The score threshold with the best F1 on the validation documents, and the
  # precision and recall there. It lies halfway between the last document
  # taken and the next one, not on the last one taken, which would leave the
  # model no margin at all.
  def best_threshold(scores, truths)
    positives = truths.count(true)
    return [scores.max.to_f + 1, {}] if positives.zero?

    ranked = scores.zip(truths).sort_by { |score, _truth| -score }
    tp = 0
    cuts = ranked.each_with_index.map do |(score, truth), index|
      tp += 1 if truth
      following = ranked[index + 1]&.first || (score - 1)
      cut(tp, index + 1, positives).merge(threshold: (score + following) / 2)
    end

    best = cuts.max_by { |candidate| candidate[:f1] }
    [best[:threshold], best.except(:threshold).transform_values { |value| value.round(4) }]
  end

  def cut(true_positives, taken, positives)
    precision = true_positives.to_f / taken
    recall = true_positives.to_f / positives
    f1 = true_positives.zero? ? 0.0 : 2 * precision * recall / (precision + recall)
    { f1:, precision:, recall: }
  end
end
