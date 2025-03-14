class AddKindOrderToMembers < ActiveRecord::Migration[7.2]
  def change
    add_column :members, :last_name, :string
    add_column :members, :kind_order, :integer, default: 0

    add_index :members, [:kind_order, :last_name], order: { kind_order: :desc, last_name: :asc }
  end
end
