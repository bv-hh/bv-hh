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
end
