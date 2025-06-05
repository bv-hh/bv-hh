class AddAdditionToMeetings < ActiveRecord::Migration[8.0]
  def change
    add_column :meetings, :note, :text
  end
end
