# frozen_string_literal: true

# Brings stored documents up to the current parser (Parsing::VERSION) by
# fetching them from ALLRIS again, a batch per district per night.
#
# Each district gets a chain of jobs: every link fetches one document, then
# schedules the next after PAUSE, until WINDOW is up or BATCH_SIZE documents
# are done. A district's ALLRIS instance therefore never sees two requests at
# once, and a slow one (Wandsbek takes 10-15 s per page) simply gets through
# fewer documents instead of piling up requests. Every link is its own job, so
# a deploy in the middle of the night loses nothing. Only the page itself is
# fetched (Document#refetch!), no attachments or images.
#
# A document whose page is stored (AllrisPage) is only parsed again: no
# request, no pause, and it does not count towards BATCH_SIZE, which exists to
# spare ALLRIS.
#
# Least recently updated documents go first. A document ALLRIS now shows only
# behind its login goes offline (Document#refetch!). When ALLRIS cannot be
# reached the document is touched, which puts it at the back of the queue for
# another night. Any other failure means this parser cannot read the page: it is
# reported and the document marked done, or the chain would ask for the same
# broken pages every night once everything else is through.
class RefetchDocumentsJob < ApplicationJob
  # 5 hours while the first catch-up after the parser rebuild is under way
  # (Wandsbek alone had 12.8k pages to fetch on 2026-10-01, ~2000 a night in
  # 2.5 hours); back to 2.5 hours once it is through.
  WINDOW = 5.hours
  BATCH_SIZE = 6_000 # above what WINDOW allows at PAUSE, so the window decides
  PAUSE = 1.second

  NETWORK_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, Net::HTTPBadResponse, SocketError, SystemCallError, EOFError,
    OpenSSL::SSL::SSLError
  ].freeze

  queue_as :documents

  def perform(district = nil, deadline = nil, remaining = BATCH_SIZE)
    if district.nil?
      District.find_each { |d| RefetchDocumentsJob.perform_later(d, WINDOW.from_now, BATCH_SIZE) }
      return
    end

    deadline ||= WINDOW.from_now
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
  rescue *NETWORK_ERRORS => e
    document.touch
    report(e, document)
  rescue StandardError => e
    document.reload.update!(parser_version: Parsing::VERSION)
    report(e, document)
  end

  def report(error, document)
    Rails.error.report(error, handled: true, context: { document_id: document.id, allris_id: document.allris_id })
  end

  def fetch(document)
    document.refetch!
  end
end
