class CreateMembers < ActiveRecord::Migration[6.1]
  def change
    create_table :groups do |t|
      t.string :name
      t.integer :allris_id

      t.timestamps
    end

    create_table :members do |t|
      t.string :name
      t.string :short_name, index: true
      t.string :kind
      t.integer :allris_id
      t.references :groups

      t.timestamps
    end

    create_table :committee_members do |t|
      t.string :kind

      t.references :members
      t.references :committees

      t.timestamps
    end
  end
end
