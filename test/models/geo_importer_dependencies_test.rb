# frozen_string_literal: true

require 'test_helper'

# The three geo importers reach the outside world, so nothing in the test suite
# exercises their fetch path — which is how an undeclared dependency reached
# production. HTTPClient arrived transitively with the google-maps gem, and
# removing that gem took it away, breaking streets:import, quarters:import and
# pois:import at once with "uninitialized constant HTTPClient".
class GeoImporterDependenciesTest < ActiveSupport::TestCase
  test 'the HTTP client the importers use is a declared dependency' do
    assert defined?(HTTPClient), 'httpclient must be declared in the Gemfile, not inherited from another gem'
  end

  test 'every importer that fetches can build its client' do
    [StreetImporter, QuarterImporter, PoiImporter].each do |importer|
      assert importer.new.respond_to?(:fetch), "#{importer} should still fetch"
    end

    client = HTTPClient.new
    assert_nothing_raised { client.ssl_config.set_default_paths }
  end
end
