# frozen_string_literal: true

# Lets a search ordered by date walk the documents newest first and stop at
# the page it shows, as it could while it ordered by documents.number. The
# expression must stay that of Document::NUMBER_BY_DATE, or the index is not
# used and every such search sorts all its matches.
class AddNumberByDateIndexToDocuments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :documents,
              "(CASE WHEN number LIKE 'XIX-%' THEN '19' || substring(number from 4) ELSE number END)",
              name: :index_documents_on_number_by_date, algorithm: :concurrently
  end
end
