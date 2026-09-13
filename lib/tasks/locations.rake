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
