class AddFormattedAddressToLocation < ActiveRecord::Migration[7.2]
  def change
    add_column :locations, :formatted_address, :string
  end
end
