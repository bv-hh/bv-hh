# frozen_string_literal: true

require 'sidekiq/scheduler'

Sidekiq.configure_server do |config|
  unless Rails.env.development?
    config.on(:startup) do
      Sidekiq.schedule = YAML.load_file(Rails.root.join('config', 'scheduler.yml'))
      Sidekiq::Scheduler.reload_schedule!
    end
  end
end
