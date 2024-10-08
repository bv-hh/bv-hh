class CreateLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :locations do |t|
      t.string :name, index: true
      t.string :place_id, index: true

      t.float :latitude
      t.float :longitude

      t.timestamps
    end

    create_table :document_locations do |t|
      t.references :document
      t.references :location

      t.timestamps
    end
  end
end
