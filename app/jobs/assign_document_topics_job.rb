# frozen_string_literal: true

# Runs after AssignDocumentLocationsJob, because the places linked to a
# document are one of the signals TopicClassifier uses. Without a document it
# fans out over those classified by an older Topic::VERSION.
class AssignDocumentTopicsJob < ApplicationJob
  LIMIT = 5000

  queue_as :documents

  def perform(document = nil)
    if document.nil?
      Document.latest_first.complete.topics_outdated.limit(LIMIT).find_each do |doc|
        AssignDocumentTopicsJob.perform_later(doc)
      end
    else
      document.assign_topics!
    end
  end
end
