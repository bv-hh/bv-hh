# frozen_string_literal: true

namespace :streets do
  desc 'Import the official Hamburg street register (gazetteer) from the WFS'
  task import: :environment do
    total = StreetImporter.import!
    puts "Imported #{total} streets"
  end

  # Re-runs location extraction (gazetteer + NER) over every document of the
  # current legislation so existing documents pick up newly recognised streets.
  # Re-analysis is additive and idempotent: extract_locations! overwrites the
  # document's extracted names and assignment uses find_or_create_by!, so no
  # duplicate document_locations are created. Pass a district name to limit the
  # scope, e.g. `rake "streets:reanalyze[Altona]"`.
  desc 'Re-analyze street names in all documents of the current legislation'
  task :reanalyze, [:district] => :environment do |_task, args|
    districts = if args[:district].present?
      [District.find_by!(name: args[:district])]
    else
      District.all.to_a
    end

    total = 0
    districts.each do |district|
      count = Document.current_legislation(district).count
      total += count
      puts "#{district.name}: enqueuing #{count} documents"

      Document.current_legislation(district).find_each do |document|
        ExtractDocumentLocationsJob.perform_later(document)
      end
    end

    puts "Enqueued #{total} documents for re-analysis"
  end
end
