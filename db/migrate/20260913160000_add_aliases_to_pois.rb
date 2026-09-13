# frozen_string_literal: true

# Documents call it "Stadtpark"; OpenStreetMap calls it "Hamburger Stadtpark".
# The city qualifier is on 60 of the imported features and never in the prose,
# so each POI carries the spellings a document might use alongside its own.
#
# An array column rather than a rewritten lookup key, because the alternative —
# stripping the qualifier from the query instead — loses the district: plain
# "Stadtpark" would then resolve to the Hamburger Stadtpark even in a document
# from Eimsbüttel, which has a Stadtpark of its own.
class AddAliasesToPois < ActiveRecord::Migration[8.1]
  def change
    add_column :pois, :aliases, :string, array: true, null: false, default: []
    add_index :pois, :aliases, using: :gin
  end
end
