# frozen_string_literal: true

# The page ALLRIS served for a record, byte for byte as fetched, so a parser
# change can be applied by re-parsing instead of downloading 70k pages again
# (see RefetchDocumentsJob). Deflated by the app, about 4 KB a page, which is
# why Postgres is told not to try compressing the column a second time.
class CreateAllrisPages < ActiveRecord::Migration[8.1]
  def change
    create_table :allris_pages do |t|
      t.references :record, polymorphic: true, null: false, index: { unique: true }
      t.binary :compressed_body, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end

    reversible do |direction|
      direction.up { execute 'ALTER TABLE allris_pages ALTER COLUMN compressed_body SET STORAGE EXTERNAL' }
    end
  end
end
