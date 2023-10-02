class AddExpiredToGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :groups, :expired_at, :date
  end
end
