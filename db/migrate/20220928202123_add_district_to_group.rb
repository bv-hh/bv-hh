class AddDistrictToGroup < ActiveRecord::Migration[6.1]
  def change
    add_reference :groups, :district, index: true
  end
end
