# frozen_string_literal: true

# Gazetteer-resolved locations were created without a formatted_address (only
# the Google path set it). Backfill them from the matching street register entry.
class BackfillGazetteerFormattedAddresses < ActiveRecord::Migration[8.1]
  def up
    streets_by_key = Street.where.not(street_key: nil).index_by(&:street_key)

    gazetteer_locations = Location.where(formatted_address: nil).where("place_id LIKE 'gazetteer:%'")
    gazetteer_locations.find_each do |location|
      street = streets_by_key[location.place_id.delete_prefix('gazetteer:')]
      next if street.nil?

      # Backfill only; skip validations/callbacks so we don't touch updated_at.
      location.update_columns(formatted_address: street.formatted_address) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def down
    # No-op: cannot distinguish backfilled values from later edits.
  end
end
