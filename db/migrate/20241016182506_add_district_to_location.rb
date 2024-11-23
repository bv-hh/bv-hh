class AddDistrictToLocation < ActiveRecord::Migration[7.2]
  def change
    add_reference :locations, :district, index: true
  end
end
