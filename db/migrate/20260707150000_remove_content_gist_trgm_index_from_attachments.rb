# frozen_string_literal: true

# The GiST trigram index on attachments.content has a hard per-row size limit
# (index rows must fit in 8191 bytes), so extracting text from a larger
# attachment fails with PG::ProgramLimitExceeded and the AttachmentExtractJob
# can never persist that content. Nothing relies on this index: content is
# searched via the tsvector full-text index, and no query uses trigram KNN
# (`<->`) ordering, which is the only thing GiST offers over GIN here. The GIN
# trigram index (content_text_gin_trgm_idx) — which has no such size limit —
# stays in place to back any ILIKE/similarity lookups.
class RemoveContentGistTrgmIndexFromAttachments < ActiveRecord::Migration[8.1]
  def up
    remove_index :attachments, name: 'content_text_gist_trgm_idx'
  end

  def down
    execute 'CREATE INDEX content_text_gist_trgm_idx ON attachments USING gist (content gist_trgm_ops)'
  end
end
