# frozen_string_literal: true

# Denormalises each Location's Quarters and its normalized street name onto
# the row itself, so the feed and the Quarter pages can be answered with one
# array-overlap and one equality instead of joining out to streets or running
# geometry at request time.
#
# street_name is needed because the two creation paths normalise differently:
# gazetteer locations store an already Street.normalize'd string in
# extracted_name, while NER/Google locations store inflected, punctuated text.
# Matching either normalized_name or name alone would silently drop one path.
class AddQuartersToLocations < ActiveRecord::Migration[8.1]
  def change
    change_table :locations, bulk: true do |t|
      t.string :quarters, array: true, null: false, default: []
      t.string :street_name
    end

    add_index :locations, :quarters, using: :gin
    add_index :locations, :street_name
  end
end
