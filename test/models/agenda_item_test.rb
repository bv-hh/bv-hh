# frozen_string_literal: true

require 'test_helper'

class AgendaItemTest < ActiveSupport::TestCase
  setup do
    @meeting = meetings(:rega_ewi_oct)
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
