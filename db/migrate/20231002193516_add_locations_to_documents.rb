class AddLocationsToDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :documents, :extracted_locations, :string, array: true, default: []
    add_column :documents, :locations_extracted_at, :timestamp, default: nil
  end
end
