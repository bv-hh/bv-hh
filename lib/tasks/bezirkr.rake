# frozen_string_literal: true

namespace :bezirkr do
  desc 'Split time into start and end'
  task split_times: :environment do
    Meeting.find_each do |meeting|
      start_time = meeting.time&.split('-')&.first&.squish
      end_time = meeting.time&.split('-')&.last&.squish
      meeting.update_columns(start_time: start_time, end_time: end_time) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
