# frozen_string_literal: true

require 'test_helper'

class Mcp::ArchiveToolTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    # ArchiveTool filters by meeting date within the last N days; the shared
    # fixtures are years old, so build a fresh, recent proposal to match against.
    meeting = @district.meetings.create!(allris_id: 9_101, title: 'Aktuelle Sitzung',
                                         date: 3.days.ago.to_date, committee: committees(:rega_ewi))
    @document = @district.documents.create!(allris_id: 9_102, number: '21-9999',
                                            title: 'Antrag zur Sache', kind: 'Antrag',
                                            author: 'SPD-Fraktion', full_text: 'Inhalt')
    @document.agenda_items.create!(meeting:, number: 'Ö1', title: 'Antrag zur Sache')
  end

  test 'call returns recent documents' do
    result = Mcp::ArchiveTool.call.structured_content

    assert_includes result[:documents].pluck('number'), '21-9999'
  end

  test 'call filters by document type and authoring party' do
    result = Mcp::ArchiveTool.call(types: 'proposals', party: 'SPD').structured_content
    numbers = result[:documents].pluck('number')

    assert_includes numbers, '21-9999'
  end

  test 'call excludes documents authored by a different party' do
    result = Mcp::ArchiveTool.call(types: 'proposals', party: 'CDU').structured_content

    assert_not_includes result[:documents].pluck('number'), '21-9999'
  end

  test 'call returns an error for an unknown district' do
    result = Mcp::ArchiveTool.call(district: 'atlantis').structured_content

    assert result.dig(:error, :message).present?
  end
end
