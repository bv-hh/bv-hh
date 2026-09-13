# frozen_string_literal: true

# The places table cached Google Places responses so a repeated query cost
# nothing. With Google gone there is nothing to cache: every source is a local
# register, already a table.
class DropPlaces < ActiveRecord::Migration[8.1]
  def change
    drop_table :places do |t|
      t.string :query, null: false
      t.json :locations
      t.integer :district_id, null: false
      t.timestamps
      t.index :district_id
      t.index :query
    end
  end
end
