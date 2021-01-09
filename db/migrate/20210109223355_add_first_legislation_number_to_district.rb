class AddFirstLegislationNumberToDistrict < ActiveRecord::Migration[6.0]
  def change
    add_column :districts, :first_legislation_number, :string
  end
end
