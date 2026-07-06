# frozen_string_literal: true

class CreateMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :memberships do |t|
      t.references :committee, foreign_key: true
      t.references :member, foreign_key: true
      t.string :role

      t.timestamps
    end

    add_index :memberships, %i[committee_id member_id], unique: true
  end
end
