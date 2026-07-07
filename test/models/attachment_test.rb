# frozen_string_literal: true

require 'test_helper'

class AttachmentTest < ActiveSupport::TestCase
  setup do
    @district = districts(:hamburg_nord)
    @document = @district.documents.create!(allris_id: 987_654)
  end

  # Guards against re-adding a GiST trigram index on content: GiST index rows
  # must fit in 8191 bytes, so extracted text larger than that would raise
  # PG::ProgramLimitExceeded on save (see AttachmentExtractJob#extract_text!).
  test 'stores extracted content larger than the GiST trigram row-size limit' do
    big_content = 'wort ' * 3000 # ~15 KB, well over 8191 bytes

    attachment = Attachment.create!(district: @district, attachable: @document, name: 'big', content: big_content)

    assert_predicate attachment, :persisted?
    assert_equal big_content, attachment.reload.content
  end
end
