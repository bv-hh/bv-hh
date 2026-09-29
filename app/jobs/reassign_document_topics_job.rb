# frozen_string_literal: true

# Enqueues AssignDocumentTopicsJob for every document classified by an older
# Topic::VERSION, optionally in one district: what `rake topics:reassign` does,
# but inside the worker, so a deploy can start it with `rake
# topics:reassign_later` and return at once. Enqueued in batches, one insert
# per batch rather than one per document.
class ReassignDocumentTopicsJob < ApplicationJob
  BATCH_SIZE = 1000

  queue_as :documents

  # Returns the number of documents enqueued.
  def perform(district = nil)
    documents = Document.complete.topics_outdated
    documents = documents.where(district: district) if district

    count = 0
    documents.in_batches(of: BATCH_SIZE) do |batch|
      jobs = batch.map { |document| AssignDocumentTopicsJob.new(document) }
      ActiveJob.perform_all_later(jobs)
      count += jobs.size
    end
    count
  end
end
