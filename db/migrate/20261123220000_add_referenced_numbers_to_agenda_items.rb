# frozen_string_literal: true

# The Drucksache numbers an agenda item's title and minutes name, so a
# Drucksache page can list the meetings that mention it
# (Document#mentioning_agenda_items). As for documents: a constant default
# rewrites no rows, the short lock_timeout keeps the column from queueing
# writes, and the index is built without blocking them. Both steps can run
# again if the other failed. rake agenda_items:references fills the column.
class AddReferencedNumbersToAgendaItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    transaction do
      execute "SET LOCAL lock_timeout = '5s'"
      add_column :agenda_items, :referenced_numbers, :string, array: true, default: [], null: false, if_not_exists: true
    end
    # An index left invalid by a failed concurrent build would satisfy
    # if_not_exists.
    remove_index :agenda_items, :referenced_numbers, algorithm: :concurrently, if_exists: true
    add_index :agenda_items, :referenced_numbers, using: :gin, algorithm: :concurrently
  end

  def down
    remove_column :agenda_items, :referenced_numbers
  end
end
