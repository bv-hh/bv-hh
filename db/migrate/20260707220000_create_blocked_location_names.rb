# frozen_string_literal: true

# Names that look like places to the NER model but are not: agency acronyms
# (BUKEA, LSBG), organisations (Stadtreinigung Hamburg), other cities, generic
# nouns. Left alone they reach Google Places, which answers for anything, and
# become pinned Locations — "Parkanlagen" at some arbitrary park.
#
# A table rather than a constant because the useful list is derived from the
# corpus and grows with it, and because editors need to add one by hand.
class CreateBlockedLocationNames < ActiveRecord::Migration[8.1]
  def change
    create_table :blocked_location_names do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :source, null: false, default: 'computed'
      t.integer :district_count, default: 0, null: false
      t.integer :occurrences, default: 0, null: false
      t.timestamps
    end

    add_index :blocked_location_names, :normalized_name, unique: true
    add_index :blocked_location_names, :source
  end
end
