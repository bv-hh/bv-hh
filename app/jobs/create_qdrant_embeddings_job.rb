class CreateQdrantEmbeddingsJob < ApplicationJob
  queue_as :default

  def perform(document)
    document.create_qdrant_embeddings
  end
end
