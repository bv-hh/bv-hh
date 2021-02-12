class AddStartAndEndTimeToMeeting < ActiveRecord::Migration[6.1]
  def change
    add_column :meetings, :start_time, :time
    add_column :meetings, :end_time, :time
  end
end
