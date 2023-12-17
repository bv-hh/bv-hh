class AddMinutesSearchIndex < ActiveRecord::Migration[7.1]
  def change
    enable_extension('pg_trgm') unless extensions.include?('pg_trgm')

    execute "CREATE INDEX ON agenda_items USING gin((setweight(to_tsvector('german', title), 'A') ||
    setweight(to_tsvector('german', minutes), 'B')))"

    execute 'CREATE INDEX agenda_items_title_gin_trgm_idx  ON agenda_items USING gin (title gin_trgm_ops)'
    execute 'CREATE INDEX agenda_items_title_gist_trgm_idx  ON agenda_items USING gist (title gist_trgm_ops)'
    execute 'CREATE INDEX agenda_items_minutes_gin_trgm_idx  ON agenda_items USING gin (minutes gin_trgm_ops)'
    execute 'CREATE INDEX agenda_items_minutes_gist_trgm_idx  ON agenda_items USING gist (minutes gist_trgm_ops)'
  end
end
