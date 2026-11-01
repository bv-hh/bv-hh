# frozen_string_literal: true

# Matters before the Hamburgische Bürgerschaft and the Drucksachen they consist
# of, imported from ParlDok (see Proceeding and ProceedingPaper).
class CreateProceedings < ActiveRecord::Migration[8.1]
  def change
    create_table :proceedings do |t|
      t.integer :parldok_process_id
      t.integer :period, null: false
      t.integer :number, null: false
      t.string :title, null: false
      t.text :abstract
      t.string :state
      t.jsonb :steps, null: false, default: []
      t.date :date
      t.text :full_text
      t.datetime :checked_at
      t.timestamps
    end
    add_index :proceedings, :parldok_process_id, unique: true
    add_index :proceedings, :date

    create_table :proceeding_papers do |t|
      t.references :proceeding, null: false, foreign_key: true
      t.integer :parldok_id, null: false
      t.integer :period, null: false
      t.integer :number, null: false
      t.string :kind, null: false
      t.string :title, null: false
      t.date :date
      t.text :full_text
      t.timestamps
    end
    add_index :proceeding_papers, :parldok_id, unique: true
    add_index :proceeding_papers, %i[period number], unique: true
  end
end
