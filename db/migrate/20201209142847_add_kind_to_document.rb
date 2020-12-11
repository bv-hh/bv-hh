class AddKindToDocument < ActiveRecord::Migration[6.0]
  def change
    add_column :documents, :kind, :string, index: true
  end
end
