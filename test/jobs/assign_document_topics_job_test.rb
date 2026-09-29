# frozen_string_literal: true

require 'test_helper'

class AssignDocumentTopicsJobTest < ActiveJob::TestCase
  setup do
    @document = districts(:hamburg_nord).documents.create!(allris_id: 9_801, title: 'Sanierung des Spielplatzes')
  end

  test 'assigns the topics and records the version' do
    AssignDocumentTopicsJob.perform_now(@document)

    @document.reload
    assert_includes @document.topics, 'spielplaetze'
    assert_equal Topic::VERSION, @document.topics_version
  end

  test 'does not touch updated_at' do
    @document.update_columns(updated_at: 1.year.ago) # rubocop:disable Rails/SkipsModelValidations

    assert_no_changes -> { @document.reload.updated_at } do
      AssignDocumentTopicsJob.perform_now(@document)
    end
  end

  test 'assigning locations enqueues the topics' do
    assert_enqueued_with(job: AssignDocumentTopicsJob, args: [@document]) do
      AssignDocumentLocationsJob.perform_now(@document)
    end
  end
end
