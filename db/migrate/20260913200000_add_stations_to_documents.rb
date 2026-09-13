# frozen_string_literal: true

# Station references found in the text, as the register spells them.
#
# They cannot live in extracted_locations: a station is called "Barmbek", which
# is a Stadtteil, or "Sengelmannstraße", which is a street, and on the plain
# name path both already resolve correctly and must keep doing so. What makes
# it a station is the "U/S" or "Haltestelle" prefix in the prose, which only
# TransitGazetteer sees. Same reasoning as documents.quarters.
class AddStationsToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :stations, :string, array: true, null: false, default: []
    add_index :documents, :stations, using: :gin
  end
end
