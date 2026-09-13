# frozen_string_literal: true

# A Drucksache that names a Stadtteil outright — "Spielplätze in Langenhorn" —
# used to be geocoded by Google into a point at the Stadtteil's centroid, which
# is the wrong shape for an area and put a pin in the middle of it. Record the
# mention on the document instead.
#
# Names rather than a join table on purpose: QuarterImporter replaces the table
# wholesale on every run, so quarter ids are not stable and nothing may hold a
# foreign key to them.
class AddQuartersToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :quarters, :string, array: true, null: false, default: []
    add_index :documents, :quarters, using: :gin
  end
end
