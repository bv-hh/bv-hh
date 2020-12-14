class AddOldestMeetingDateToDistrict < ActiveRecord::Migration[6.0]
  def change
    add_column :districts, :oldest_allris_meeting_date, :date
    rename_column :districts, :oldest_allris_id, :oldest_allris_document_id
  end
end
