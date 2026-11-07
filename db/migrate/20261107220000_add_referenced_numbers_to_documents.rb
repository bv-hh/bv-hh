# frozen_string_literal: true

# The Drucksache numbers a document's text names, resolved to documents when
# shown (Document#referenced_documents, #citing_documents). The column default
# is a constant, so adding it rewrites no rows; the short lock_timeout keeps it
# from queueing writes behind a long transaction. The index is built without
# blocking writes and with no timeout, as it waits for older transactions.
# Both steps can run again if the other failed.
class AddReferencedNumbersToDocuments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    transaction do
      execute "SET LOCAL lock_timeout = '5s'"
      add_column :documents, :referenced_numbers, :string, array: true, default: [], null: false, if_not_exists: true
    end
    # An index left invalid by a failed concurrent build would satisfy
    # if_not_exists.
    remove_index :documents, :referenced_numbers, algorithm: :concurrently, if_exists: true
    add_index :documents, :referenced_numbers, using: :gin, algorithm: :concurrently
  end

  def down
    remove_column :documents, :referenced_numbers
  end
end
