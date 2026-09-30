# frozen_string_literal: true

# A learned classifier for one topic: a logistic regression on the document
# embeddings (DocumentEmbedding), trained by TopicTrainer with the rules as
# teacher. It finds documents that are about the topic in words no rule knows.
#
# The score of a document is its embedding's dot product with weights, plus
# bias: the log-odds that the document is about the topic. It is computed by
# pgvector in Postgres; a document is tagged when it reaches threshold (on
# the same log-odds scale).
#
# The classifier adds to the rules and never removes a rule's topic.
# documents.classified_topics holds the topics only the classifier found, so
# documents.topics minus those are the rules' topics, and reclassifying the
# corpus needs no rule run: `rake topics:classify`, and nightly after the
# embeddings by EmbedDocumentsJob.
class TopicModel < ApplicationRecord
  scope :current, -> { where(model: DocumentEmbedder::NAME) }

  # Log-odds of every current topic model for the embedding e, as a column
  # named score next to the model's columns.
  SCORE = 'topic_models.bias - (document_embeddings.embedding <#> topic_models.weights)'

  # The topic keys the classifier gives a document, in the order of
  # config/topics.yml. None without an embedding of the current model.
  def self.predict(document)
    keys = current.joins('JOIN document_embeddings ON document_embeddings.model = topic_models.model')
                  .where(document_embeddings: { document_id: document.id })
                  .where("#{SCORE} >= topic_models.threshold")
                  .pluck(:topic)
    Topic.keys & keys
  end

  # Brings documents.topics and documents.classified_topics of the whole
  # corpus in line with the current models, in one statement. Returns the
  # number of documents changed.
  def self.classify_all!
    keys = "ARRAY[#{Topic.keys.map { |key| connection.quote(key) }.join(', ')}]"
    order = ->(topic) { "array_position(#{keys}::varchar[], #{topic})" }

    connection.exec_update(<<~SQL.squish)
      WITH predicted AS (
        SELECT document_embeddings.document_id, array_agg(topic_models.topic) AS topics
        FROM document_embeddings
        JOIN topic_models ON topic_models.model = document_embeddings.model
        WHERE topic_models.model = #{connection.quote(DocumentEmbedder::NAME)}
          AND #{SCORE} >= topic_models.threshold
        GROUP BY document_embeddings.document_id
      ), revised AS (
        SELECT documents.id,
               ARRAY(SELECT unnest(documents.topics) EXCEPT SELECT unnest(documents.classified_topics))::varchar[] AS rules,
               COALESCE(predicted.topics, '{}') AS predicted
        FROM documents
        LEFT JOIN predicted ON predicted.document_id = documents.id
        WHERE predicted.document_id IS NOT NULL OR documents.classified_topics <> '{}'
      ), added AS (
        SELECT id, rules,
               ARRAY(SELECT topic FROM unnest(predicted) topic WHERE topic <> ALL(rules)
                     ORDER BY #{order['topic']})::varchar[] AS added
        FROM revised
      )
      UPDATE documents
      SET classified_topics = added.added,
          topics = ARRAY(SELECT topic FROM unnest(added.rules || added.added) topic ORDER BY #{order['topic']})
      FROM added
      WHERE documents.id = added.id AND documents.classified_topics IS DISTINCT FROM added.added
    SQL
  end
end
