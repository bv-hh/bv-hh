# frozen_string_literal: true

require 'test_helper'

class DocumentsHelperTest < ActionView::TestCase
  test 'document_format scrubs the old parser whitespace only from documents not yet re-fetched' do
    document = documents(:document_7)
    document.content = "<p><span>\u00a0</span></p><p>Text</p>"

    document.parser_version = nil

    assert_equal ' <p>Text</p>', document_format(document, :content)

    document.parser_version = Parsing::VERSION

    assert_equal document.content, document_format(document, :content)
  end

  test 'document_title is the title as text' do
    assert_equal 'Spiel & Sport', document_title(Document.new(title: 'Spiel &amp; Sport'))
  end

  test 'document_places leaves out every place named like except' do
    document = Document.new
    heilwig = Location.new(id: 1, name: 'Heilwigstraße')
    document.locations = [Location.new(id: 2, name: 'Heilwigstraße'), Location.new(id: 3, name: 'Alsterdorfer Straße'), heilwig]

    assert_equal ['Alsterdorfer Straße'], document_places(document, except: heilwig).map(&:name)
  end

  test 'highlight_text keeps decoded angle brackets as text' do
    assert_equal 'Planung &lt;<mark>Elbufer</mark>&gt;', highlight_text('Planung <Elbufer>', ['Elbufer'])
  end
end
