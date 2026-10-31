# frozen_string_literal: true

# Stores the vector Document.search matches and ranks by. As an expression
# index it served the match, but ranking still analysed the full text of every
# match again: 2-3 s for a common word across all Bezirke on production.
#
# Adding a stored generated column rewrites the table and holds an exclusive
# lock on documents meanwhile, about a minute on production (analysing every
# document alone took 33 s there). Deploy in a quiet hour. The expression
# index goes first so the rewrite does not rebuild it, and the new index is
# built concurrently by the next migration.
class AddSearchVectorToDocuments < ActiveRecord::Migration[8.1]
  def up
    # Fail the deploy rather than queue behind a long query: a waiting
    # exclusive lock blocks every reader that comes after it.
    execute "SET LOCAL lock_timeout = '10s'"
    remove_index :documents, name: 'documents_expr_idx'
    add_column :documents, :search_vector, :virtual, type: :tsvector, stored: true, as: <<~SQL.squish
      setweight(to_tsvector('german'::regconfig, coalesce(title, '')), 'A') ||
      setweight(to_tsvector('german'::regconfig, coalesce(full_text, '')), 'B')
    SQL
  end

  def down
    remove_column :documents, :search_vector
    add_index :documents, "(setweight(to_tsvector('german'::regconfig, (title)::text), 'A'::\"char\") || " \
                          "setweight(to_tsvector('german'::regconfig, full_text), 'B'::\"char\"))",
              name: 'documents_expr_idx', using: :gin
  end
end
