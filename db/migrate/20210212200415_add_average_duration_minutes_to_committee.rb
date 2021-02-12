class AddAverageDurationMinutesToCommittee < ActiveRecord::Migration[6.1]
  def change
    add_column :committees, :average_duration, :integer
  end
end
