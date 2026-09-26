# frozen_string_literal: true

# Brings stored documents up to the current parser (Parsing::VERSION) by
# fetching them from ALLRIS again, a batch per district per night.
#
# Each district gets a chain of jobs: every link fetches one document, then
# schedules the next after PAUSE, until WINDOW is up or BATCH_SIZE documents
# are done. A district's ALLRIS instance therefore never sees two requests at
# once, and a slow one (Wandsbek takes 10-15 s per page) simply gets through
# fewer documents instead of piling up requests. Every link is its own job, so
# a deploy in the middle of the night loses nothing.
#
# A document whose page is stored (AllrisPage) is only parsed again: no
# request, no pause, and it does not count towards BATCH_SIZE, which exists to
# spare ALLRIS.
#
# Least recently updated documents go first. A document that fails is touched,
# which puts it at the back of the queue instead of blocking the chain every
# night.
class RefetchDocumentsJob < ApplicationJob
  WINDOW = 2.5.hours
  BATCH_SIZE = 2_000
  PAUSE = 3.seconds

  queue_as :documents

  def perform(district = nil, deadline = nil, remaining = BATCH_SIZE)
    if district.nil?
      District.find_each { |d| RefetchDocumentsJob.perform_later(d, WINDOW.from_now, BATCH_SIZE) }
      return
    end

    return if remaining <= 0 || Time.current > deadline

    document = district.documents.parsed_before(Parsing::VERSION).order(:updated_at, :id).first
    return if document.nil?

    if document.allris_page
      attempt(document) { document.reparse! }
      RefetchDocumentsJob.perform_later(district, deadline, remaining)
    else
      attempt(document) { fetch(document) }
      RefetchDocumentsJob.set(wait: PAUSE).perform_later(district, deadline, remaining - 1)
    end
  end

  private

  def attempt(document)
    yield
  rescue StandardError => e
    document.touch
    Rails.error.report(e, handled: true, context: { document_id: document.id, allris_id: document.allris_id })
  end

  def fetch(document)
    document.retrieve_from_allris!
  end
end
