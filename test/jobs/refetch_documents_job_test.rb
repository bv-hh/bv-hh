# frozen_string_literal: true

require 'test_helper'

class RefetchDocumentsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @district = districts(:hamburg_nord)
    @deadline = 1.hour.from_now
    @fetched = []
  end

  # A job whose fetch records the document and marks it parsed, as
  # retrieve_from_allris! would, instead of going to ALLRIS.
  def job(&fetch)
    fetched = @fetched
    fetch ||= ->(document) { document.update!(parser_version: Parsing::VERSION) }
    RefetchDocumentsJob.new.tap do |job|
      job.define_singleton_method(:fetch) do |document|
        fetched << document
        fetch.call(document)
      end
    end
  end

  test 'without a district it starts one chain per district' do
    assert_enqueued_jobs District.count, only: RefetchDocumentsJob do
      RefetchDocumentsJob.perform_now
    end
  end

  test 'a link fetches the least recently updated outdated document and schedules the next' do
    oldest = @district.documents.first
    oldest.update!(updated_at: 10.years.ago)
    @district.documents.where.not(id: oldest.id).update_all(parser_version: Parsing::VERSION)
    @district.documents.create!(allris_id: 9_101, parser_version: Parsing::VERSION)

    assert_enqueued_with(job: RefetchDocumentsJob, args: [@district, @deadline, 4]) do
      job.perform(@district, @deadline, 5)
    end
    assert_equal [oldest], @fetched
    assert_equal Parsing::VERSION, oldest.reload.parser_version
  end

  test 'the chain ends at the deadline, after the batch, and when nothing is left' do
    assert_no_enqueued_jobs do
      job.perform(@district, 1.minute.ago, 5)
      job.perform(@district, @deadline, 0)
    end
    assert_empty @fetched

    @district.documents.update_all(parser_version: Parsing::VERSION)

    assert_no_enqueued_jobs { job.perform(@district, @deadline, 5) }
    assert_empty @fetched
  end

  test 'a failing document goes to the back of the queue and the chain goes on' do
    failing = @district.documents.first
    failing.update!(updated_at: 10.years.ago)

    assert_enqueued_with(job: RefetchDocumentsJob) do
      job { raise Net::ReadTimeout }.perform(@district, @deadline, 5)
    end
    assert_nil failing.reload.parser_version
    assert_operator failing.updated_at, :>, 1.minute.ago
  end

  test 'a document with a stored page is parsed again instead of fetched' do
    document = @district.documents.first
    document.update!(updated_at: 10.years.ago)
    AllrisPage.create!(record: document, body: AllrisFixtures.page('hamburg_nord', 'vo020.html'), fetched_at: Time.current)

    assert_enqueued_with(job: RefetchDocumentsJob, args: [@district, @deadline, 5], at: nil) do
      job.perform(@district, @deadline, 5)
    end
    assert_empty @fetched
    assert_equal Parsing::VERSION, document.reload.parser_version
  end

  test 'a page the parser cannot read is marked done so the chain does not ask for it every night' do
    broken = @district.documents.first
    broken.update!(updated_at: 10.years.ago)

    assert_enqueued_with(job: RefetchDocumentsJob) do
      job { raise NoMethodError, "undefined method 'css' for nil" }.perform(@district, @deadline, 5)
    end
    assert_equal Parsing::VERSION, broken.reload.parser_version
  end

  test 'a district can be refetched by hand without a deadline' do
    assert_enqueued_with(job: RefetchDocumentsJob) do
      job.perform(@district)
    end
  end
end
