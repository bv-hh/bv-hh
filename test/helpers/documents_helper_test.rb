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

  test 'link_documents links known numbers by the rule of the references, with or without suffix and dash' do
    referenced = documents(:document_227) # 21-4512
    content = "<p>Siehe Drs. #{referenced.number}, Drs. 21–4512 und Drs. 21-9999, nicht 22/4512.</p>"

    linked = Nokogiri::HTML.fragment(link_documents(content, referenced.district))

    assert_equal ['21-4512', '21–4512'], linked.css('a').map(&:text)
    assert(linked.css('a').all? { |a| a['href'] == document_path(referenced) })
  end
end
