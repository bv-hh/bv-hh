# frozen_string_literal: true

# Nightly: embeds the documents that are new or changed since the last run.
# The model takes ~0.8 GB, so it is not loaded into the worker, which would
# keep it: `rake embeddings:update` runs as a process of its own and gives the
# memory back when it exits.
class EmbedDocumentsJob < ApplicationJob
  queue_as :documents

  def perform
    system(Rails.root.join('bin/rails').to_s, 'embeddings:update', exception: true)
  end
end
