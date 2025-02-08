class AddOrderToDistricts < ActiveRecord::Migration[7.1]
  def change
    add_column :districts, :order, :integer, default: 0

    reversible do |dir|
      dir.up do
        District::ORDER.each_with_index do |district, index|
          District.find_by(name: district)&.update!(order: index)
        end
      end
    end
  end
end
