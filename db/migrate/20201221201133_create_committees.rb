class CreateCommittees < ActiveRecord::Migration[6.0]
  def change
    create_table :committees do |t|
      t.references :district
      t.integer :allris_id, index: true
      t.string :name
      t.integer :order, default: 0
      t.boolean :public, default: true

      t.timestamps
    end

    add_reference :meetings, :committee, index: true
    add_index :meetings, :allris_id
  end
end
