class AddInactiveToCommittee < ActiveRecord::Migration[6.0]
  def change
    add_column :committees, :inactive, :boolean, default: false
  end
end
