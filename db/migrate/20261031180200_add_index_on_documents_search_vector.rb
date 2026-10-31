# frozen_string_literal: true

class AddIndexOnDocumentsSearchVector < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :documents, :search_vector, using: :gin, algorithm: :concurrently
  end
end
