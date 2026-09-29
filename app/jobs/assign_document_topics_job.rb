# frozen_string_literal: true

# Runs after AssignDocumentLocationsJob, because the places linked to a
# document are one of the signals TopicClassifier uses. The whole corpus after
# a bump of Topic::VERSION goes through ReassignDocumentTopicsJob.
class AssignDocumentTopicsJob < ApplicationJob
  queue_as :documents

  def perform(document)
    document.assign_topics!
  end
end
