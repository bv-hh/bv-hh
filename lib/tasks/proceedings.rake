# frozen_string_literal: true

namespace :proceedings do
  # Walks every Drucksache of the period and imports the ones not there yet, so
  # an interrupted run simply continues. ParlDok wants requests spaced out
  # (ParldokClient::DELAY): a first run over a whole period takes hours.
  #
  # Only ProceedingImporter::PERIODS: the current one, which
  # CheckForProceedingUpdatesJob also keeps up to date every night, and the one
  # before, which is closed and needs this task once.
  #
  #   rake proceedings:import         # both, current first
  #   rake "proceedings:import[22]"   # one of them
  desc 'Import Drucksachen of the Bürgerschaft from ParlDok'
  task :import, %i[period] => :environment do |_task, args|
    periods = args[:period].present? ? [args[:period].to_i] : ProceedingImporter::PERIODS
    importer = ProceedingImporter.new
    periods.each do |period|
      count = importer.import!(period)
      puts "Imported #{count} Drucksachen of period #{period}"
    end
  end
end
