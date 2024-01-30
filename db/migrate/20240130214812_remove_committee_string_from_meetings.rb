class RemoveCommitteeStringFromMeetings < ActiveRecord::Migration[7.1]
  def change
    remove_column :meetings, :committee, :string
  end
end
