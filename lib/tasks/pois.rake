# frozen_string_literal: true

namespace :pois do
  # Around 45 Overpass requests against instances that throttle. Answers are
  # cached as they arrive, so a run that loses one to a 504 can be re-run and
  # will retry only what is missing. Nothing is written to the table until the
  # set is complete — a partial import would silently delete a whole category,
  # since the import empties the table first.
  desc 'Import named OpenStreetMap features in Hamburg into the POI gazetteer'
  task :import, [:path] => :environment do |_task, args|
    importer = PoiImporter.new(path: args[:path].presence)
    resuming = importer.cached_keys
    puts "Resuming: #{resuming.size} of #{importer.queries.size} queries already answered" if resuming.any?

    begin
      total = importer.import!
    rescue PoiImporter::IncompleteImportError => e
      warn "Incomplete: #{e.failures.size} queries did not answer."
      e.failures.each { |key, error| warn "  #{key}: #{error.class}" }
      warn 'Nothing was written. Re-run pois:import to retry only these; the rest is cached.'
      exit 1
    end

    puts "Imported #{total} POIs (#{Poi.pinnable.count} pinnable, #{Poi.where(generic: true).count} generic)"
  end

  desc 'Discard the cached Overpass answers, so the next import fetches everything'
  task clear_cache: :environment do
    PoiImporter.new.clear_cache!
    puts 'Cleared the Overpass answer cache'
  end

  desc 'Recompute the alternative spellings on existing POIs'
  task rebuild_aliases: :environment do
    puts "Updated #{Poi.rebuild_aliases!} of #{Poi.count} POIs"
  end

  # The measurement behind the decision to remove Google entirely.
  #
  # Every name extraction has ever produced is replayed through the resolution
  # order of Location.determine_locations, and reported by the step that would
  # answer it. The bucket that matters is "would reach Google": what the POI
  # gazetteer answers there is what Google can stop being asked for, and what
  # stays unresolved is the price of removing it.
  #
  # Read-only — it creates nothing.
  desc 'Report how much of the corpus the POI gazetteer answers instead of Google'
  task coverage: :environment do
    report = PoiCoverage.new.run

    puts "\nExtracted name instances: #{report.total}"
    puts "#{'resolved by'.ljust(14)}#{'instances'.rjust(10)}#{'distinct'.rjust(10)}#{'share'.rjust(8)}"
    PoiCoverage::BUCKETS.each do |bucket|
      data = report.counts[bucket]
      puts "#{bucket.to_s.ljust(14)}#{data[:instances].to_s.rjust(10)}#{data[:names].size.to_s.rjust(10)}" \
           "#{report.share(data[:instances]).rjust(8)}"
    end

    puts "\nNames the street register does not know: #{report.google} instances"
    puts "  answered by the POI gazetteer and the trigram match: #{report.answered} " \
         "(#{report.google_share(report.answered)})"
    puts "  generic POI name, deliberately unpinned: #{report.counts[:poi_generic][:instances]}"
    puts "  unresolved, and now left unresolved: #{report.unresolved} (#{report.google_share(report.unresolved)})"

    %i[poi fuzzy poi_generic unresolved].each do |bucket|
      puts "\n#{bucket} examples: #{report.examples[bucket].uniq.first(20).join(', ')}"
    end

    found, sampled, stations = report.transit_sample
    puts "\nStation references (sample of #{sampled} documents): #{found} documents"
    puts "  stations named: #{stations.first(20).join(', ')}"

    puts "\nExisting Google-sourced locations: #{report.google_locations.count}"
    puts "  reproducible from the local registers: #{report.reproducible_locations}"
  end
end
