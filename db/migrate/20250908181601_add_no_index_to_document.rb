class AddNoIndexToDocument < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :noindex, :boolean, default: false, null: false
  end
end
