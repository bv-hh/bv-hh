# frozen_string_literal: true

# The feed no longer filters on noindex — that column is a search-engine
# directive, not a visibility rule — so the partial index has to stop requiring
# it, or it no longer matches the query it exists for.
class DropNoindexFromFeedIndex < ActiveRecord::Migration[8.1]
  INDEX = 'index_documents_on_created_at_public_complete'

  def up
    remove_index :documents, name: INDEX
    add_index :documents, :created_at, order: { created_at: :desc },
              where: 'non_public = false AND title IS NOT NULL', name: INDEX
  end

  def down
    remove_index :documents, name: INDEX
    add_index :documents, :created_at, order: { created_at: :desc },
              where: 'non_public = false AND title IS NOT NULL AND noindex = false', name: INDEX
  end
end
