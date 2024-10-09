class AddExtractedNameToLocation < ActiveRecord::Migration[7.2]
  def change
    add_column :locations, :extracted_name, :string
  end
end
