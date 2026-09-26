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
      assert_equal AgendaItemParsingTest.page(slug).b, agenda_item.allris_page.body
    end
  end

  def self.page(slug) = AllrisFixtures.page(slug, 'to020.html')

  test 'retrieve_from_allris! leaves minutes and result empty while ALLRIS only has empty paragraphs' do
    district = AllrisFixtures.build_district('wandsbek')
    meeting = district.meetings.create!(allris_id: 9_999_998, title: 'Sitzung', date: Date.new(2020, 1, 1))
    agenda_item = AllrisFixtures.stub_network(meeting.agenda_items.new(allris_id: 1, number: 'Ö1', title: 'TOP'))
    blank = '<div><p style="font-size:11pt"><span>&nbsp;</span></p><p><span></span></p></div>'

    agenda_item.retrieve_from_allris!(<<~HTML)
      <table class="risdeco"><tr><td>
        <a name="allrisWP"></a>#{blank}<a name="allrisBS"></a><a name="allrisAE"></a>#{blank}
      </td></tr></table>
    HTML

    assert_nil agenda_item.minutes
    assert_nil agenda_item.result
    assert_not_includes AgendaItem.with_minutes, agenda_item
  end
end
