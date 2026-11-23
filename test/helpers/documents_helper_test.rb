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

  test 'mention_excerpt marks the exact number, not one inside a longer number before it' do
    document = documents(:document_7) # 21-4776
    item = AgendaItem.new(minutes: "<p>Drs. 21-4776.1 wurde beraten. #{'Füllwort ' * 30}Später wird Drs.21-4776 nachgereicht.</p>")

    passage = mention_excerpt(item, document)

    assert_includes passage, '<mark>21-4776</mark> nachgereicht'
    assert passage.start_with?('…')
  end

  test 'mention_excerpt escapes the text and is nil where only the title names the number' do
    document = documents(:document_7)

    assert_includes mention_excerpt(AgendaItem.new(minutes: '<p>&lt;b&gt;Hinweis&lt;/b&gt; zu 21-4776</p>'), document),
                    '&lt;b&gt;Hinweis&lt;/b&gt; zu <mark>21-4776</mark>'
    assert_nil mention_excerpt(AgendaItem.new(title: 'Zu 21-4776', minutes: '<p>Ohne Nummer</p>'), document)
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
