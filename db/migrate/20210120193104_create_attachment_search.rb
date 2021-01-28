class CreateAttachmentSearch < ActiveRecord::Migration[6.0]
  def change
    create_table :attachment_searches do |t|
    end
    reversible do |dir|
      dir.up do
        execute "CREATE INDEX ON attachments USING gin((setweight(to_tsvector('german', name), 'A') ||
        setweight(to_tsvector('german', content), 'B')))"

        execute 'CREATE INDEX name_text_gin_trgm_idx  ON attachments USING gin (name gin_trgm_ops)'
        execute 'CREATE INDEX name_text_gist_trgm_idx  ON attachments USING gist (name gist_trgm_ops)'
        execute 'CREATE INDEX content_text_gin_trgm_idx  ON attachments USING gin (content gin_trgm_ops)'
        execute 'CREATE INDEX content_text_gist_trgm_idx  ON attachments USING gist (content gist_trgm_ops)'
      end
    end
  end
end
