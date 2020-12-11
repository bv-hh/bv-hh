class AddNonPublicToDocument < ActiveRecord::Migration[6.0]
  def change
    add_column :documents, :non_public, :boolean, default: false
  end
end
