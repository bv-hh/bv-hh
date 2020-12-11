class CreateDocumentSearch < ActiveRecord::Migration[6.0]
  def change
    add_column :documents, :full_text, :text

    enable_extension('pg_trgm') unless extensions.include?('pg_trgm')

    execute "CREATE INDEX ON documents USING gin((setweight(to_tsvector('german', title), 'A') ||
    setweight(to_tsvector('german', full_text), 'B')))"

    execute 'CREATE INDEX title_gin_trgm_idx  ON documents USING gin (title gin_trgm_ops)'
    execute 'CREATE INDEX title_gist_trgm_idx  ON documents USING gist (title gist_trgm_ops)'
    execute 'CREATE INDEX full_text_gin_trgm_idx  ON documents USING gin (full_text gin_trgm_ops)'
    execute 'CREATE INDEX full_text_gist_trgm_idx  ON documents USING gist (full_text gist_trgm_ops)'
  end
end
