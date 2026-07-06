# frozen_string_literal: true

class CreateParties < ActiveRecord::Migration[8.0]
  def change
    create_table :parties do |t|
      t.integer :allris_id
      t.references :district, foreign_key: true
      t.string :name
      t.boolean :inactive, default: false, null: false

      t.timestamps
    end

    add_index :parties, %i[district_id allris_id], unique: true
  end
end
