# frozen_string_literal: true

require 'test_helper'

class ReassignDocumentTopicsJobTest < ActiveJob::TestCase
  setup do
    Document.update_all(topics_version: Topic::VERSION)
    @outdated = documents(:document_7)
    @outdated.update_columns(topics_version: Topic::VERSION - 1) # rubocop:disable Rails/SkipsModelValidations
  end

  test 'enqueues topic assignment for documents classified by an older version only' do
    assert_equal 1, ReassignDocumentTopicsJob.perform_now

    assert_enqueued_with(job: AssignDocumentTopicsJob, args: [@outdated])
    assert_enqueued_jobs 1, only: AssignDocumentTopicsJob
  end

  test 'documents never classified count as outdated' do
    documents(:document_4).update_columns(topics_version: nil) # rubocop:disable Rails/SkipsModelValidations

    assert_equal 2, ReassignDocumentTopicsJob.perform_now
  end

  test 'can be limited to one district' do
    other = District.create!(name: 'Altona', order: 2, allris_base_url: 'https://example.test')

    assert_equal 0, ReassignDocumentTopicsJob.perform_now(other)
    assert_equal 1, ReassignDocumentTopicsJob.perform_now(districts(:hamburg_nord))
  end
end
