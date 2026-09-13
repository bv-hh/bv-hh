# frozen_string_literal: true

# A gazetteer of named OpenStreetMap features in Hamburg — parks, playgrounds,
# schools, cemeteries, squares — alongside the street and Quarter registers.
#
# It exists to answer the names the street register cannot: today those go to
# Google Places, which returns a result for *anything*, which is why the
# blocklist has to exist at all. A local gazetteer matched on exact names
# answers the real ones and stays silent on the rest.
class CreatePois < ActiveRecord::Migration[8.1]
  def change
    create_table :pois do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      # The OSM tag the feature was accepted for, e.g. "leisure=park". Kept so
      # the allowlist can be audited against the corpus after the fact.
      t.string :category, null: false
      t.string :osm_type, null: false
      t.bigint :osm_id, null: false
      t.float :latitude, null: false
      t.float :longitude, null: false
      # Derived from the Quarter polygons at import time, exactly like
      # Location.place_attributes does for a Location — a POI is a point, so it
      # has one Quarter and one district, unlike a street.
      t.string :quarter
      t.string :quarters, array: true, null: false, default: []
      t.integer :district_number
      t.string :postal_code
      # Names too common to pin: 40 features called "Spielplatz" cannot resolve
      # to a point. Computed at import; see PoiImporter#mark_generic!.
      t.boolean :generic, null: false, default: false
      # A station, reachable only through TransitGazetteer — a bare "Barmbek"
      # must stay a Stadtteil, while "U/S Barmbek" is a point. Kept out of every
      # plain-name lookup by the +pinnable+ scope.
      t.boolean :transit, null: false, default: false
      t.timestamps
    end

    add_index :pois, :normalized_name
    add_index :pois, %i[osm_type osm_id], unique: true
    add_index :pois, :district_number
    add_index :pois, :transit
    add_index :pois, :quarters, using: :gin
  end
end
