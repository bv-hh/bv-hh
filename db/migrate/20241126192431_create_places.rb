# frozen_string_literal: true

class CreatePlaces < ActiveRecord::Migration[7.2]
  def change
    create_table :places do |t|
      t.string :query, null: false
      t.json :locations
      t.timestamps
    end

    add_index :places, :query
  end
end
