# frozen_string_literal: true

require 'test_helper'

class AgendaItemReferencesTest < ActiveSupport::TestCase
  # A test below adds a Bezirk, which District.lookup would keep after rollback.
  teardown { District.instance_variable_set(:@districts, nil) }

  setup do
    @document = documents(:document_7) # 21-4776, Hamburg-Nord
    @committee = committees(:rega_ewi)
    @meeting = meetings(:rega_ewi_oct)
  end

  def item(**attributes)
    AgendaItem.create!(meeting: @meeting, title: 'Verschiedenes', number: 'Ö9', **attributes)
  end

  test 'finds Drucksache numbers in the title, minutes and result, written with an entity too' do
    agenda_item = item(title: 'Nachfrage zu Drs. 21-4512', minutes: '<p>Siehe Drs. 21&ndash;4728.1.</p>', result: '<p>Vgl. 21-4800</p>')

    assert_equal %w[21-4512 21-4728.1 21-4800], agenda_item.referenced_numbers
  end

  test "leaves out its own Drucksache's family and extracts again when the minutes change" do
    agenda_item = item(document: @document, minutes: '<p>Zur Drs. 21-4776 und 21-4776.1, siehe auch 21-4512</p>')

    assert_equal %w[21-4512], agenda_item.referenced_numbers

    agenda_item.update!(minutes: '<p>Kein Bezug</p>')

    assert_empty agenda_item.referenced_numbers
  end

  test 'a Drucksache lists the items of its Bezirk naming it exactly, newest first, without its own' do
    later = Meeting.create!(committee: @committee, district: @committee.district, date: @meeting.date + 7, title: 'Sitzung', allris_id: 9_999_100)
    older = item(minutes: '<p>Drs. 21-4776 wird nachgereicht.</p>')
    newer = AgendaItem.create!(meeting: later, title: 'Antrag zu Drs. 21-4776', number: 'Ö2')
    item(minutes: '<p>Drs. 21-4776.1</p>')
    item(document: @document, minutes: '<p>Drs. 21-4776</p>')

    assert_equal [newer, older], @document.mentioning_agenda_items.to_a
  end

  test 'a Drucksache leaves out the items of the Drucksachen it is told to exclude' do
    citing = Document.create!(district: @document.district, number: '21-9997', title: 'Nennt 21-4776', allris_id: 9_997)
    item(document: citing, title: 'Nachfrage (bez. Drs. 21-4776)')
    loose = item(title: 'Verschiedenes', minutes: '<p>Zu Drs. 21-4776</p>')

    assert_equal [loose], @document.mentioning_agenda_items(exclude: [citing.id]).to_a
  end

  test 'a Drucksache does not list an item of another Bezirk naming the same number' do
    altona = District.create!(name: 'Altona', allris_base_url: 'https://sitzungsdienst-altona.hamburg.de', order: 2)
    meeting = Meeting.create!(district: altona, date: @meeting.date, title: 'Sitzung', allris_id: 9_999_101)
    AgendaItem.create!(meeting:, title: 'Verschiedenes', minutes: '<p>Drs. 21-4776</p>')

    assert_empty @document.mentioning_agenda_items
  end
end
