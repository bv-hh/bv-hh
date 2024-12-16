class AddDistrictToPlace < ActiveRecord::Migration[7.2]
  def change
    add_reference :places, :district, null: false, foreign_key: true
  end
end
