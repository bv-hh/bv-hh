# == Schema Information
#
# Table name: meetings
#
#  id           :integer          not null, primary key
#  district_id  :integer
#  title        :string
#  date         :date
#  time         :string
#  room         :string
#  location     :string
#  allris_id    :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  committee_id :integer
#  start_time   :time
#  end_time     :time
#  note         :text
#
# Indexes
#
#  index_meetings_on_allris_id     (allris_id)
#  index_meetings_on_committee_id  (committee_id)
#  index_meetings_on_district_id   (district_id)
#

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
