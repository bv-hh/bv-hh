# frozen_string_literal: true

class AddTopicsToDocuments < ActiveRecord::Migration[8.1]
  def change
    change_table :documents, bulk: true do |t|
      t.string :topics, array: true, default: [], null: false
      t.integer :topics_version
      t.index :topics, using: :gin
    end
  end
end
