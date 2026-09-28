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
      assert_equal Parsing::VERSION, document.parser_version
      assert_no_match(/<span|style=|&nbsp;|\u00a0/, "#{document.content}#{document.resolution}", "#{slug}: expected Word formatting to be gone")
      assert_no_match(/&(amp|lt|gt|quot);/, document.full_text, "#{slug}: expected decoded full text")
    end
  end

  test 'retrieve_from_allris! keeps the spaces between words Word put in spans of their own' do
    district = AllrisFixtures.build_district('wandsbek')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_025_666))

    document.retrieve_from_allris!(AllrisFixtures.page('wandsbek', 'vo020.html'))

    assert_includes document.full_text, 'Der Geschäftsstelle der Bezirksversammlung'
    assert_includes document.full_text, "\n1. Keine Vermietung mehr"
  end

  test 'retrieve_from_allris! enqueues location extraction for a document with text' do
    district = AllrisFixtures.build_district('hamburg_nord')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_016_851))

    assert_enqueued_with(job: ExtractDocumentLocationsJob) do
      document.retrieve_from_allris!(AllrisFixtures.page('hamburg_nord', 'vo020.html'))
    end
  end

  test 'retrieve_body puts unlabelled sections into the content, in page order' do
    html = Nokogiri::HTML.parse(<<~HTML, nil, 'UTF-8')
      <table><tr><td bgcolor="white">
        <div><p>Sachverhalt:</p><p>Die Frage.</p></div>
        <div><p>FREIE UND HANSESTADT HAMBURG</p><p>Die Antwort.</p></div>
        <div><p><span>Petitum/</span><span>Beschluss:</span></p><p>Um Kenntnisnahme wird gebeten.</p></div>
        <div><p>[1] https://example.org/</p></div>
        <div><p>Anlage/n: keine</p></div>
      </td></tr></table>
    HTML
    document = Document.new

    document.retrieve_body(html)

    assert_equal "Die Frage.\nFREIE UND HANSESTADT HAMBURG\nDie Antwort.\n[1] https://example.org/", Parsing.text(document.content)
    assert_equal '<p>Um Kenntnisnahme wird gebeten.</p>', document.resolution
    assert_nil document.attached
  end

  test 'retrieve_from_allris! takes the content of a page that does not label it' do
    district = AllrisFixtures.build_district('altona') # Altona never writes "Sachverhalt:"
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_018_473))

    document.retrieve_from_allris!(AllrisFixtures.page('altona', 'vo020.html'))

    assert_includes document.content, 'Mobilitätsausschuss empfiehlt'
    assert_not_includes document.content, 'Petitum'
  end

  test 'retrieve_from_allris! keeps the answer Harburg puts in a section of its own' do
    district = AllrisFixtures.build_district('harburg')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_014_761))

    document.retrieve_from_allris!(AllrisFixtures.page('harburg', 'vo020.html'))

    assert_includes document.full_text, 'Bezirksamt Harburg'
  end

  test 'retrieve_from_allris! stores the page as fetched' do
    district = AllrisFixtures.build_district('wandsbek')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_025_666))
    source = AllrisFixtures.page('wandsbek', 'vo020.html')

    document.retrieve_from_allris!(source)

    assert_equal source.b, document.allris_page.reload.body
  end

  test 'retrieve_from_allris! stores nothing for a page that is not public' do
    document = AllrisFixtures.build_district('wandsbek').documents.new(allris_id: 1)

    document.retrieve_from_allris!("<html>#{Document::NON_PUBLIC}</html>")

    assert_predicate document, :non_public?
    assert_nil document.allris_page
  end

  test 'reparse! rebuilds the document from its stored page' do
    district = AllrisFixtures.build_district('wandsbek')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_025_666))
    document.retrieve_from_allris!(AllrisFixtures.page('wandsbek', 'vo020.html'))
    parsed = document.attributes.slice('title', 'content', 'resolution', 'full_text')
    document.update!(content: '<p><span>alt</span></p>', full_text: 'alt', parser_version: nil)

    document.reparse!

    assert_equal parsed, document.reload.attributes.slice('title', 'content', 'resolution', 'full_text')
    assert_equal Parsing::VERSION, document.parser_version
  end

  test 'refetch! parses and stores the page but leaves attachments and images alone' do
    district = AllrisFixtures.build_district('wandsbek')
    document = district.documents.create!(allris_id: 1_025_666)
    document.define_singleton_method(:retrieve_attachments) { |_html| raise 'must not sync attachments' }
    document.define_singleton_method(:retrieve_images) { |_html| raise 'must not fetch images' }
    source = AllrisFixtures.page('wandsbek', 'vo020.html')

    assert_enqueued_with(job: ExtractDocumentLocationsJob) { document.refetch!(source) }
    assert_includes document.reload.full_text, 'Der Geschäftsstelle der Bezirksversammlung'
    assert_equal source.b, document.allris_page.body
  end

  test 'refetch! takes a document offline when ALLRIS shows it only behind its login' do
    [
      '<html><a href="noauth.asp">Anmelden</a></html>',
      "<html>#{Document::NON_PUBLIC}</html>",
    ].each do |page|
      document = AllrisFixtures.build_district('wandsbek').documents.create!(allris_id: 1, title: 'Alt', content: '<p>Alt</p>')

      document.refetch!(page)

      assert_predicate document.reload, :non_public?
      assert_equal Parsing::VERSION, document.parser_version
      assert_nil document.allris_page
      assert_not_includes Document.all, document
    end
  end

  test 'reparse! leaves location extraction alone when the text did not change' do
    district = AllrisFixtures.build_district('wandsbek')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_025_666))
    document.retrieve_from_allris!(AllrisFixtures.page('wandsbek', 'vo020.html'))
    clear_enqueued_jobs

    assert_no_enqueued_jobs(only: ExtractDocumentLocationsJob) { document.reparse! }
  end

  test 'reparse! reassigns topics when only the title changed' do
    district = AllrisFixtures.build_district('wandsbek')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_025_666))
    document.retrieve_from_allris!(AllrisFixtures.page('wandsbek', 'vo020.html'))
    document.update_columns(title: 'Alter Titel') # rubocop:disable Rails/SkipsModelValidations
    clear_enqueued_jobs

    assert_enqueued_with(job: AssignDocumentTopicsJob, args: [document]) { document.reparse! }
    assert_no_enqueued_jobs(only: ExtractDocumentLocationsJob)
  end

  test 'reparse! leaves topics alone when nothing changed' do
    district = AllrisFixtures.build_district('wandsbek')
    document = AllrisFixtures.stub_network(district.documents.new(allris_id: 1_025_666))
    document.retrieve_from_allris!(AllrisFixtures.page('wandsbek', 'vo020.html'))
    clear_enqueued_jobs

    assert_no_enqueued_jobs(only: AssignDocumentTopicsJob) { document.reparse! }
  end
end
