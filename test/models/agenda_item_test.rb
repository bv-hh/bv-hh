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

  test 'recognises the public question time by its many names' do
    ['Öffentliche Fragestunde', 'Aktuelle Bürgerfragestunde', 'Begrüßung und öffentliche Fragestunde',
     'Anliegen der Bürgerinnen und Bürger und Öffentliche Fragestunde 1. Teil',
     'Eröffnung der Sitzung /Anliegen der Bürgerinnen und Bürger'].each do |title|
      assert_predicate AgendaItem.new(title:), :question_time?, title
    end

    ['Anfragen / Auskunftsersuchen', 'Mündliche Anfragen', 'Tagesordnungspunkte mit Referierenden- und Bürgerbeteiligung',
     nil].each do |title|
      assert_not_predicate AgendaItem.new(title:), :question_time?, title.inspect
    end
  end

  test 'minutes_search finds every form of a word, in the minutes or the title' do
    meeting = @meeting.district.meetings.create!(title: 'Sitzung', date: Date.new(2024, 3, 1))
    by_minutes = meeting.agenda_items.create!(number: 'Ö 4', title: 'Verschiedenes', minutes: '<p>Zwei Spielplätze werden saniert.</p>')
    by_title = meeting.agenda_items.create!(number: 'Ö 5', title: 'Spielplatz Quokkaweg', minutes: '<p>Kenntnis genommen.</p>')
    meeting.agenda_items.create!(number: 'Ö 6', title: 'Spielplatz ohne Protokoll')

    assert_equal [by_minutes, by_title].sort_by(&:id), AgendaItem.minutes_search('Spielplatz').sort_by(&:id)
  end

  test 'minutes_search with prefix takes the last word as the beginning of one' do
    meeting = @meeting.district.meetings.create!(title: 'Sitzung', date: Date.new(2024, 3, 1))
    item = meeting.agenda_items.create!(number: 'Ö 4', title: 'Verschiedenes', minutes: 'Der Quokkaweg wird saniert.')

    assert_empty AgendaItem.minutes_search('Quokka')
    assert_equal [item], AgendaItem.minutes_search('Quokka', nil, prefix: true).to_a
  end

  test 'minutes_search finds nothing for a term without words' do
    assert_empty AgendaItem.minutes_search(' &!: ')
  end
end
