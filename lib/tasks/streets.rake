# frozen_string_literal: true

namespace :streets do
  desc 'Import the official Hamburg street register (gazetteer) from the WFS'
  task import: :environment do
    total = StreetImporter.import!
    puts "Imported #{total} streets"
  end

  # Re-runs location extraction (gazetteer + NER) over existing documents so they
  # pick up newly recognised streets. Re-analysis is additive and idempotent:
  # extract_locations! overwrites the document's extracted names and assignment
  # uses find_or_create_by!, so no duplicate document_locations are created.
  #
  #   rake streets:reanalyze              # current legislation, all districts
  #   rake "streets:reanalyze[Altona]"    # one district
  #   rake "streets:reanalyze[,all]"      # every complete document
  #
  # The `all` scope matters after the gazetteer is first populated, or after it
  # learns new spellings: documents older than the current legislation were
  # analysed against whatever the register held at the time.
  desc 'Re-analyze street names in existing documents'
  task :reanalyze, %i[district scope] => :environment do |_task, args|
    districts = if args[:district].present?
      [District.find_by!(name: args[:district])]
    else
      District.all.to_a
    end

    total = 0
    districts.each do |district|
      scope = if args[:scope] == 'all'
        Document.complete.where(district: district)
      else
        Document.current_legislation(district)
      end

      count = scope.count
      total += count
      puts "#{district.name}: enqueuing #{count} documents"

      scope.find_each { |document| ExtractDocumentLocationsJob.perform_later(document) }
    end

    puts "Enqueued #{total} documents for re-analysis"
  end
end
