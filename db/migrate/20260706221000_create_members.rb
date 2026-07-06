# frozen_string_literal: true

class CreateMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :members do |t|
      t.integer :allris_id
      t.references :district, foreign_key: true
      t.references :party, foreign_key: true
      t.string :name
      t.string :kind
      t.boolean :inactive, default: false, null: false

      t.timestamps
    end

    add_index :members, %i[district_id allris_id], unique: true
  end
end
