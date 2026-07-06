# frozen_string_literal: true

class CreateAttendances < ActiveRecord::Migration[8.0]
  def change
    create_table :attendances do |t|
      t.references :meeting, foreign_key: true
      t.references :member, foreign_key: true
      t.string :name
      t.string :party_hint
      t.string :role
      t.boolean :substitute, default: false, null: false
      t.boolean :present, default: true, null: false

      t.timestamps
    end

    add_index :attendances, %i[meeting_id member_id], unique: true
  end
end
