class AddLatLngToDistrict < ActiveRecord::Migration[7.2]
  def change
    add_column :districts, :ne_lat, :float
    add_column :districts, :ne_lng, :float
    add_column :districts, :sw_lat, :float
    add_column :districts, :sw_lng, :float
  end
end
