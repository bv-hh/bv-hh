# frozen_string_literal: true

require 'test_helper'

# Exercises Document#retrieve_from_allris! against one real vo020 document page
# captured from every district's ALLRIS instance (see test/support). The HTML
# differs subtly between instances, so parsing every district guards the crawler
# against instance-specific regressions. Attachment/image downloads are stubbed;
# the follow-up location-extraction job is only recorded (:test queue adapter).
class DocumentParsingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  AllrisFixtures.each_district do |slug, info|
    test "retrieve_from_allris! parses a #{slug} document" do
      district = AllrisFixtures.build_district(slug)
      document = AllrisFixtures.stub_network(district.documents.new(allris_id: info['document_id']))

      document.retrieve_from_allris!(AllrisFixtures.page(slug, 'vo020.html'))

      assert_predicate document, :persisted?
      assert_predicate document, :complete?, "#{slug}: expected a title to be extracted"
      assert_match(/\A\d{2}-\d/, document.number, "#{slug}: expected an ALLRIS document number like 22-1234")
      assert document.kind.present?, "#{slug}: expected a document kind"
      assert document.full_text.present?, "#{slug}: expected full text"
      assert_not document.non_public?, "#{slug}: fixture should be a public document"
    end
  end

  test 'retrieve_from_allris! enqueues location extraction for a document with content' do
    district = AllrisFixtures.build_district('hamburg_nord')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_016_851))

    assert_enqueued_with(job: ExtractDocumentLocationsJob) do
      document.retrieve_from_allris!(AllrisFixtures.page('hamburg_nord', 'vo020.html'))
    end
  end
end
