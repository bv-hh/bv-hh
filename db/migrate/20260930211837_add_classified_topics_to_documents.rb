# frozen_string_literal: true

class AddClassifiedTopicsToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :classified_topics, :string, array: true, default: [], null: false
  end
end
