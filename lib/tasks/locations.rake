# frozen_string_literal: true

namespace :locations do
  # Dry run by default: the list is a judgement call and deserves a read before
  # it starts suppressing things. `rake "locations:blocklist[apply]"` writes it.
  desc 'Show (or apply) the blocklist of names that only look like places'
  task :blocklist, [:apply] => :environment do |_task, args|
    blocklist = LocationBlocklist.new
    candidates = blocklist.candidates

    candidates.each do |candidate|
      puts format('%<count>5d  %<districts>dd  %<name>s',
                  count: candidate.occurrences, districts: candidate.district_count, name: candidate.name)
    end

    if args[:apply] == 'apply'
      puts "Applied: #{blocklist.apply!} blocked names (manual entries untouched)"
    else
      puts "#{candidates.size} candidates. Re-run as locations:blocklist[apply] to write them."
    end
  end

  # Everything the Google era left behind, found by asking of each row whether
  # the registers would produce it today. Broader than purge_blocked, which only
  # knows about blocked names.
  #
  # Two questions, because there are two ways to be wrong. A row can be a place
  # no register names any more, and a document can claim a row its own district
  # would never resolve — the residue of the cross-district reuse that let one
  # word pin all seven. The first deletes locations, the second only the links.
  desc 'Show (or delete) locations no register would produce any more'
  task :sweep, [:apply] => :environment do |_task, args|
    cleanup = LocationCleanup.new
    stale = cleanup.stale
    doomed = stale.to_set { |entry| entry.location.id }
    links = cleanup.stale_links.reject { |entry| doomed.include?(entry.location.id) }

    stale.sort_by { |entry| -entry.documents }.each do |entry|
      puts format('%<docs>4d docs  %<name>-40s %<reason>s',
                  docs: entry.documents, name: entry.location.name.to_s.truncate(40), reason: entry.reason)
    end

    puts '' if links.any?
    links.sort_by { |entry| -entry.documents }.each do |entry|
      puts format('%<docs>4d docs  %<name>-40s not a place in %<district>s',
                  docs: entry.documents, name: entry.location.name.to_s.truncate(40), district: entry.district.name)
    end

    if args[:apply] == 'apply'
      result = cleanup.apply!
      puts "Deleted #{result.locations} locations and #{result.links} stale document links"

      Document.where(id: result.document_ids).find_each(&:assign_locations_later!)
      puts "Enqueued #{result.document_ids.size} documents for reassignment"
    else
      puts "#{stale.size} of #{Location.count} locations would be deleted, " \
           "plus #{links.sum(&:documents)} document links on rows that stay. " \
           'Re-run as locations:sweep[apply].'
    end
  end

  # Assignment only, without re-running extraction.
  #
  # streets:reanalyze re-reads every document's text through the gazetteer and
  # the NER model, which is the expensive half and the one that rarely needs to
  # happen: extraction writes documents.extracted_locations, and a change to how
  # a *name* resolves to a place does not change the names. Use this after an
  # import that alters the registers, and streets:reanalyze only when the
  # extraction itself changed.
  #
  # Additive, like assignment always is — it creates links and removes none.
  # locations:sweep is what removes, and it enqueues exactly the documents it
  # touched, so a sweep needs no separate run of this.
  desc 'Re-assign locations from the names already extracted, skipping extraction'
  task :reassign, [:district] => :environment do |_task, args|
    scope = Document.complete.where.not(extracted_locations: []).or(Document.complete.where.not(stations: []))
    scope = scope.where(district: District.find_by!(name: args[:district])) if args[:district].present?

    count = scope.count
    scope.find_each(&:assign_locations_later!)
    puts "Enqueued #{count} documents for re-assignment"
  end

  # Locations created before a name was blocked stay until they are cleared out.
  # Destroying them takes their document_locations with them.
  desc 'Delete existing locations whose name is now blocked'
  task :purge_blocked, [:apply] => :environment do |_task, args|
    blocked = Location.all.select { |location| Location.blocked?(location.extracted_name) }

    blocked.each do |location|
      puts format('%<docs>4d docs  %<name>s  (%<address>s)',
                  docs: location.documents.count, name: location.name, address: location.formatted_address)
    end

    if args[:apply] == 'apply'
      count = blocked.each(&:destroy).size
      puts "Deleted #{count} locations"
    else
      puts "#{blocked.size} locations would be deleted. Re-run as locations:purge_blocked[apply]."
    end
  end
end
