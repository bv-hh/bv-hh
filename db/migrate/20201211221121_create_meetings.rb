class CreateMeetings < ActiveRecord::Migration[6.0]
  def change
    create_table :meetings do |t|
      t.references :district
      t.string :title
      t.string :committee
      t.date :date
      t.string :time
      t.string :room
      t.string :location
      t.integer :allris_id

      t.timestamps
    end

    create_table :agenda_items do |t|
      t.references :meeting
      t.references :document
      t.string :title
      t.string :number

      t.timestamps
    end
  end
end
