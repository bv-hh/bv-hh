# frozen_string_literal: true

require 'test_helper'

class ErrorLogSubscriberTest < ActiveSupport::TestCase
  test 'a handled error is logged with its context' do
    output = StringIO.new
    subscriber = ErrorLogSubscriber.new(Logger.new(output))

    subscriber.report(Net::ReadTimeout.new, handled: true, severity: :warning, context: { document_id: 7 }, source: 'application')

    assert_match(/WARN .*\[application\] handled Net::ReadTimeout: Net::ReadTimeout \{"document_id":7\}/, output.string)
  end

  test 'it is subscribed to Rails.error' do
    assert(Rails.error.instance_variable_get(:@subscribers).any?(ErrorLogSubscriber))
  end
end
