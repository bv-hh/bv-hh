# frozen_string_literal: true

# The 104 official Hamburg Quarters with their boundaries, imported from the
# "ALKIS Verwaltungsgrenzen" WFS. Geometry is kept as raw GeoJSON coordinates in
# jsonb rather than a PostGIS type: point-in-polygon runs once per Location (at
# creation and in the backfill), never in a request, so a Ruby ray cast over 104
# memoized polygons is enough and saves both the extension and the adapter swap.
class CreateQuarters < ActiveRecord::Migration[8.1]
  def change
    create_table :quarters do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :key, null: false
      t.string :number
      t.integer :bezirk
      t.string :bezirk_name
      t.jsonb :geometry, null: false
      # Bounding box, precomputed so covering? can reject ~103 of 104 candidates
      # before touching a single ring.
      t.float :min_lat
      t.float :max_lat
      t.float :min_lng
      t.float :max_lng
      t.timestamps
    end

    add_index :quarters, :slug, unique: true
    add_index :quarters, :key, unique: true
    add_index :quarters, :bezirk
    add_index :quarters, :name
  end
end
