class AddAuthorToDocument < ActiveRecord::Migration[6.0]
  def change
    add_column :documents, :author, :string
  end
end
