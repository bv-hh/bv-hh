# frozen_string_literal: true

require 'test_helper'

class MeetingTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @meeting = @district.meetings.create!(allris_id: 1_003_143, title: 'Sitzung der Bezirksversammlung', date: Date.new(2025, 12, 11))
  end

  test 'minutes_download_params extracts the public Niederschrift form values' do
    params = @meeting.send(:minutes_download_params, file_fixture('to010.html').read)

    assert_equal 'DOLFDNR=1392414&options=64', params
  end

  test 'minutes_download_params returns nil when there is no protocol form' do
    assert_nil @meeting.send(:minutes_download_params, '<html><body>no minutes</body></html>')
  end
end
