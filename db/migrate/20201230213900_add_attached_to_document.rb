class AddAttachedToDocument < ActiveRecord::Migration[6.0]
  def change
    add_column :documents, :attached, :text
  end
end
