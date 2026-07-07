# frozen_string_literal: true

require 'test_helper'

# Exercises AgendaItem#retrieve_from_allris! against one real to020 agenda-item
# page per district. Each captured page comes from an already-minuted meeting so
# the parser has published protocol text to extract. Attachment downloads are
# stubbed so the test runs offline.
class AgendaItemParsingTest < ActiveSupport::TestCase
  AllrisFixtures.each_district do |slug, info|
    test "retrieve_from_allris! parses a #{slug} agenda item" do
      district = AllrisFixtures.build_district(slug)
      meeting = district.meetings.create!(allris_id: 9_999_999, title: 'Sitzung', date: Date.new(2020, 1, 1))
      agenda_item = AllrisFixtures.stub_network(
        meeting.agenda_items.new(allris_id: info['agenda_item_id'], number: 'Ö1', title: 'TOP')
      )

      agenda_item.retrieve_from_allris!(AllrisFixtures.page(slug, 'to020.html'))

      assert_predicate agenda_item, :persisted?
      assert_predicate agenda_item, :logged?, "#{slug}: a minuted item should count as logged"
      assert agenda_item.minutes.present?, "#{slug}: expected minutes text"
      assert_operator agenda_item.strip_tags(agenda_item.minutes).squish.length, :>=, 40,
                      "#{slug}: expected substantial minutes text"
    end
  end
end
