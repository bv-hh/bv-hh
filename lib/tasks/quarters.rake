# frozen_string_literal: true

namespace :quarters do
  desc 'Import the official Hamburg Quarter boundaries from the WFS'
  task import: :environment do
    total = QuarterImporter.import!
    puts "Imported #{total} Quarters"
  end

  # Fills locations.quarters and locations.street_name for rows created before
  # those columns existed. Idempotent: it recomputes from the register and the
  # polygons every time, so it is also the way to repair the columns after a
  # streets:import or quarters:import changes the underlying data.
  desc 'Backfill Quarters and street names onto existing locations'
  task assign_locations: :environment do
    total = 0
    changed = 0

    repaired = 0

    Location.find_each do |location|
      total += 1
      # Snap known-bad coordinates back into Hamburg first, so the Quarters
      # computed below describe where the location actually is.
      repaired += 1 if location.repair_coordinates!

      attributes = Location.place_attributes(location.name, location.latitude, location.longitude)
      next if attributes.all? { |key, value| location.public_send(key) == value }

      location.update_columns(attributes.merge(updated_at: Time.current)) # rubocop:disable Rails/SkipsModelValidations
      changed += 1
    end

    puts "Checked #{total} locations, updated #{changed}, repaired coordinates for #{repaired}"
  end

  # Fills documents.quarters from names already extracted, without re-running
  # NER over the corpus. Use this when a full streets:reanalyze is not wanted;
  # reanalysis recomputes the column anyway.
  desc 'Backfill Stadtteil mentions onto existing documents'
  task backfill_documents: :environment do
    total = 0
    changed = 0

    Document.complete.find_each do |document|
      total += 1
      quarters = document.extracted_quarters
      next if quarters.sort == document.quarters.sort

      document.update_columns(quarters: quarters, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
      changed += 1
    end

    puts "Checked #{total} documents, updated #{changed}"
  end
end
