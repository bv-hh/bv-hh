# frozen_string_literal: true

require 'test_helper'

# Behavioural tests for the Document model. Cross-district HTML parsing lives in
# document_parsing_test.rb; this covers search, scopes and helpers.
class DocumentTest < ActiveSupport::TestCase
  setup { @district = districts(:hamburg_nord) }

  test 'search matches documents by a stemmed title term' do
    numbers = Document.search('Eingabe').map(&:number)

    assert_includes numbers, '21-4776' # title: "Eingabe: Heilwigstraße ..."
  end

  test 'search restricts results to the given root scope' do
    other = District.create!(name: 'Anderswo', allris_base_url: 'https://example.test')

    results = Document.search('Eingabe', root: other.documents)

    assert_empty results
  end

  test 'search ordered by date returns newest document numbers first' do
    numbers = Document.search('Eingabe', order: :date).map(&:number)

    assert_operator numbers.size, :>, 1, 'need multiple matches to assert ordering'
    assert_equal numbers.sort.reverse, numbers, 'expected descending document numbers'
    assert_includes numbers, '21-4776' # title: "Eingabe: Heilwigstraße ..."
  end

  test 'proposals scope only returns Antrag documents' do
    proposals = @district.documents.proposals

    assert_includes proposals.map(&:number), '21-4512' # kind: "Antrag"
    assert(proposals.all? { |doc| doc.kind.match?(/Antrag/i) })
  end

  test 'current_legislation returns documents from the first legislation number on' do
    documents = Document.current_legislation(@district)

    assert documents.any?
    assert(documents.all? { |doc| doc.number >= @district.first_legislation_number })
    assert(documents.all? { |doc| doc.district == @district })
  end

  test 'related_documents links a document to its parent and sibling revisions' do
    parent = @district.documents.create!(allris_id: 9_201, number: '21-5000', title: 'Stamm')
    child = @district.documents.create!(allris_id: 9_202, number: '21-5000.1', title: 'Neufassung')
    grandchild = @district.documents.create!(allris_id: 9_203, number: '21-5000.1.1', title: 'Ergänzung')

    related = child.related_documents

    assert_includes related, parent
    assert_includes related, grandchild
    assert_not_includes related, child
  end

  test 'to_param combines the parameterized title and id' do
    document = documents(:document_7)

    assert_equal "#{document.title.parameterize}-#{document.id}", document.to_param
  end

  test 'as_json exposes the district and the meetings the document appears on' do
    json = documents(:document_7).as_json

    assert_equal 'Hamburg-Nord', json[:district]
    assert_includes json[:meetings].pluck(:title), meetings(:rega_ewi_oct).title
  end
end
