# frozen_string_literal: true

require 'test_helper'

class ErrorLogSubscriberTest < ActiveSupport::TestCase
  test 'a handled error is logged with its context' do
    output = StringIO.new
    subscriber = ErrorLogSubscriber.new(Logger.new(output))

    subscriber.report(Net::ReadTimeout.new, handled: true, severity: :warning, context: { document_id: 7 }, source: 'application')

    assert_match(/WARN .*\[application\] handled Net::ReadTimeout: Net::ReadTimeout \{"document_id":7\}/, output.string)
  end

  # Rails puts the controller and the request into the context of every
  # exception a request raises. Serialising them overflowed the stack.
  test 'objects in the context are logged by class, not serialised' do
    output = StringIO.new
    subscriber = ErrorLogSubscriber.new(Logger.new(output))
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for('/documents'))

    subscriber.report(RuntimeError.new('boom'), handled: false, severity: :error,
                                                context: { request:, controller: DocumentsController.new, id: 7 })

    assert_includes output.string, '{"request":"ActionDispatch::Request","controller":"DocumentsController","id":7}'
  end

  test 'errors Rails answers with a 4xx are not logged' do
    output = StringIO.new
    subscriber = ErrorLogSubscriber.new(Logger.new(output))

    subscriber.report(ActiveRecord::RecordNotFound.new, handled: false, severity: :error, context: {})
    subscriber.report(ActionController::RoutingError.new('x'), handled: false, severity: :error, context: {})

    assert_empty output.string
  end

  test 'it is subscribed to Rails.error' do
    assert(Rails.error.instance_variable_get(:@subscribers).any?(ErrorLogSubscriber))
  end
end
