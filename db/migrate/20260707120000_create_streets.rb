# frozen_string_literal: true

class CreateStreets < ActiveRecord::Migration[8.1]
  def change
    create_table :streets do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.float :latitude
      t.float :longitude
      t.string :stadtteil
      t.string :postal_code
      t.string :street_key
      t.integer :bezirke, array: true, null: false, default: []
      t.timestamps
    end

    add_index :streets, :normalized_name
    add_index :streets, :street_key
    add_index :streets, :bezirke, using: :gin
  end
end
