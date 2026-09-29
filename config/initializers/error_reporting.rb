# frozen_string_literal: true

# Rails.error has no subscriber of its own, so an error reported as handled
# (RefetchDocumentsJob reports every document it could not read) went nowhere.
# This one writes each report to the log, with its context. Defined here rather
# than under lib/ because a subscriber registered at boot must not be reloaded.
#
# Rails reports every exception a request raises, with the controller and the
# request in the context. Serialising those recurses until the stack overflows,
# which turned every 404 and 500 into a SystemStackError, so only plain values
# are written out. Exceptions Rails answers with a 4xx (RecordNotFound,
# RoutingError, ...) are not logged at all: they are not errors of the app, and
# Rails logs them already.
class ErrorLogSubscriber
  PLAIN = [String, Symbol, Numeric, TrueClass, FalseClass, NilClass].freeze

  def initialize(logger)
    @logger = logger
  end

  def report(error, handled:, severity:, context:, source: nil)
    return if client_error?(error)

    level = { error: :error, warning: :warn }.fetch(severity, :info)
    location = error.backtrace&.find { |line| line.include?('/app/') } || error.backtrace&.first
    @logger.public_send(level, "[#{source || 'application'}] #{handled ? 'handled' : 'unhandled'} " \
                               "#{error.class}: #{error.message} #{plain(context).to_json} #{location}".strip)
  end

  private

  def plain(context)
    context.to_h.transform_values { |value| PLAIN.any? { |type| value.is_a?(type) } ? value : value.class.name }
  end

  def client_error?(error)
    status = ActionDispatch::ExceptionWrapper.rescue_responses[error.class.name]
    status.present? && Rack::Utils.status_code(status) < 500
  end
end

Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorLogSubscriber.new(Rails.logger))
end
