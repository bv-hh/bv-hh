# frozen_string_literal: true

# Indexes for the Quarter/street feed query. It drives from documents ordered
# by created_at and probes an EXISTS over document_locations, so it needs a
# descending partial index matching the feed's own filters, plus both column
# orders on the join table.
class AddFeedIndexes < ActiveRecord::Migration[8.1]
  def up
    # find_or_create_by! in Document#assign_locations! already intends this pair
    # to be unique; any duplicates are race artifacts, so collapse them before
    # the unique index goes on.
    execute <<~SQL.squish
      DELETE FROM document_locations a
      USING document_locations b
      WHERE a.id > b.id
        AND a.document_id = b.document_id
        AND a.location_id = b.location_id
    SQL

    add_index :document_locations, %i[document_id location_id], unique: true,
                                                                name: 'index_document_locations_on_document_and_location'
    add_index :document_locations, %i[location_id document_id],
              name: 'index_document_locations_on_location_and_document'

    add_index :documents, :created_at, order: { created_at: :desc },
                                       where: 'non_public = false AND title IS NOT NULL AND noindex = false',
                                       name: 'index_documents_on_created_at_public_complete'
  end

  def down
    remove_index :documents, name: 'index_documents_on_created_at_public_complete'
    remove_index :document_locations, name: 'index_document_locations_on_location_and_document'
    remove_index :document_locations, name: 'index_document_locations_on_document_and_location'
  end
end
