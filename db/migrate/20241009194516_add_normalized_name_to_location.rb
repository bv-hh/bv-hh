class AddNormalizedNameToLocation < ActiveRecord::Migration[7.2]
  def change
    add_column :locations, :normalized_name, :string
    add_index :locations, :normalized_name
  end
end
