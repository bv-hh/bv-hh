# frozen_string_literal: true

# Rails.error has no subscriber of its own, so an error reported as handled
# (RefetchDocumentsJob reports every document it could not read) went nowhere.
# This one writes each report to the log, with its context. Defined here rather
# than under lib/ because a subscriber registered at boot must not be reloaded.
class ErrorLogSubscriber
  def initialize(logger)
    @logger = logger
  end

  def report(error, handled:, severity:, context:, source: nil)
    level = { error: :error, warning: :warn }.fetch(severity, :info)
    location = error.backtrace&.find { |line| line.include?('/app/') } || error.backtrace&.first
    @logger.public_send(level, "[#{source || 'application'}] #{handled ? 'handled' : 'unhandled'} " \
                               "#{error.class}: #{error.message} #{context.to_json} #{location}".strip)
  end
end

Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorLogSubscriber.new(Rails.logger))
end
