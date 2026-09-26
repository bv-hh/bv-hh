# frozen_string_literal: true

require 'test_helper'

class AgendaItemTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @meeting = meetings(:rega_ewi_oct)
  end

  test 'linking a fetched document reassigns its topics' do
    document = @meeting.district.documents.create!(allris_id: 9_701, title: 'Neuer Radweg')
    item = @meeting.agenda_items.create!(number: 'Ö99')

    assert_enqueued_with(job: AssignDocumentTopicsJob, args: [document]) do
      item.update!(document: document)
    end
  end

  test 'linking a document not yet fetched leaves its topics to the fetch' do
    document = @meeting.district.documents.create!(allris_id: 9_702)

    assert_no_enqueued_jobs(only: AssignDocumentTopicsJob) do
      @meeting.agenda_items.create!(number: 'Ö99', document: document)
    end
  end

  test 'saving an item without a change of document does not reassign topics' do
    document = @meeting.district.documents.create!(allris_id: 9_703, title: 'Neuer Radweg')
    item = @meeting.agenda_items.create!(number: 'Ö99', document: document)

    assert_no_enqueued_jobs(only: AssignDocumentTopicsJob) do
      item.update!(minutes: 'Diskutiert')
    end
  end

  test 'caches the HTML-stripped word count on save' do
    item = @meeting.agenda_items.create!(minutes: '<p>Es wurde lange diskutiert</p>', result: 'Beschlossen')

    assert_equal 5, item.word_count # 4 words of minutes + 1 of result, tags stripped
  end

  test 'recomputes the cached word count when the text changes' do
    item = @meeting.agenda_items.create!(minutes: 'nur kurz')
    assert_equal 2, item.word_count

    item.update!(minutes: 'jetzt etwas mehr Text')

    assert_equal 4, item.reload.word_count
  end

  test 'word count is zero without minutes or result' do
    item = @meeting.agenda_items.create!(minutes: nil, result: nil)

    assert_equal 0, item.word_count
  end
end
