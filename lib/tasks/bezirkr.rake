# frozen_string_literal: true

namespace :bezirkr do

  desc 'Split time into start and end'
  task split_times: :environment do
    Meeting.find_each do |meeting|
      meeting.update_columns(start_time: meeting.time.split('-').first&.squish, end_time: meeting.time.split('-').last&.squish)
    end
  end
end
