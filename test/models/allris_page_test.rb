# == Schema Information
#
# Table name: allris_pages
#
#  id              :integer          not null, primary key
#  record_type     :string           not null
#  record_id       :integer          not null
#  compressed_body :binary           not null
#  fetched_at      :datetime         not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_allris_pages_on_record  (record_type,record_id) UNIQUE
#

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
