class CreateDistricts < ActiveRecord::Migration[6.0]
  def change
    create_table :districts do |t|
      t.string :name
      t.string :allris_base_url
      t.integer :oldest_allris_id
      t.timestamps
    end
  end
end
