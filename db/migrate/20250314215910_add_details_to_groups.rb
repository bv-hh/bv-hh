class AddDetailsToGroups < ActiveRecord::Migration[7.2]
  def change
    add_column :groups, :address, :text
    add_column :groups, :phone, :string
    add_column :groups, :fax, :string
    add_column :groups, :email, :string
    add_column :groups, :www, :string
  end
end
