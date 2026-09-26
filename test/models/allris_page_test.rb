# frozen_string_literal: true

require 'test_helper'

class AllrisPageTest < ActiveSupport::TestCase
  test 'body comes back byte for byte, compressed in between' do
    source = AllrisFixtures.page('altona', 'vo020.html')
    page = AllrisPage.create!(record: documents(:document_7), body: source, fetched_at: Time.current)

    assert_equal source.b, page.reload.body
    assert_operator page.compressed_body.bytesize, :<, source.bytesize / 3
  end
end
