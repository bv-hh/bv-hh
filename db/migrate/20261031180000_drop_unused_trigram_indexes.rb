# frozen_string_literal: true

# Trigram indexes no query uses. On production, before this migration, the
# documents ones had never been scanned (idx_scan 0) and took 970 MB, the
# GiST one on full_text 743 MB of it; Document.prefix_search ORs title,
# number and full text, which none of them can serve. The minutes ones served
# AgendaItem's ILIKE search, which now goes through agenda_items_expr_idx.
#
# The GiST index on documents.title stays: authored_by and prefix_search use
# it.
class DropUnusedTrigramIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEXES = [
    [:documents, :full_text, 'full_text_gist_trgm_idx', :gist],
    [:documents, :full_text, 'full_text_gin_trgm_idx', :gin],
    [:documents, :title, 'title_gin_trgm_idx', :gin],
    [:agenda_items, :minutes, 'agenda_items_minutes_gist_trgm_idx', :gist],
    [:agenda_items, :minutes, 'agenda_items_minutes_gin_trgm_idx', :gin],
    [:agenda_items, :title, 'agenda_items_title_gist_trgm_idx', :gist],
    [:agenda_items, :title, 'agenda_items_title_gin_trgm_idx', :gin],
  ].freeze

  def change
    INDEXES.each do |table, column, name, using|
      remove_index table, column, name:, using:, opclass: :"#{using}_trgm_ops", algorithm: :concurrently, if_exists: true
    end
  end
end
