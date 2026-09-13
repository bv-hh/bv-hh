# frozen_string_literal: true

# Derives the blocklist from the corpus itself.
#
# The signal is breadth. A real place belongs to one part of the city, so a name
# that the NER model keeps proposing across several districts — while the street
# register and the Stadtteil register have both never heard of it — is not a
# place at all. In practice that catches agency acronyms (BUKEA, LSBG, BWI),
# organisations (Stadtreinigung Hamburg, Hochbahn), legal and document
# references (Drs, hamburgisches Wegegesetz), other cities, and plain nouns
# ("Sommermonaten", "Einzelfällen").
#
# This mattered more when Google Places answered for anything: every one of
# these became a pinned Location. Now a name no register knows produces nothing
# by itself, so the list is a backstop rather than a necessity — its remaining
# job is names the registers *do* know but should not pin, such as the street
# the official register genuinely lists as "-Parkanlagen".
#
# Deliberately conservative: anything the official registers know is kept, so
# this can never blocklist a real street or Stadtteil.
class LocationBlocklist
  MIN_DISTRICTS = 3
  MIN_OCCURRENCES = 3
  BATCH = 500

  Candidate = Struct.new(:name, :normalized_name, :district_count, :occurrences, keyword_init: true)

  def self.candidates(...) = new(...).candidates
  def self.apply!(...) = new(...).apply!

  def initialize(min_districts: MIN_DISTRICTS, min_occurrences: MIN_OCCURRENCES)
    @min_districts = min_districts
    @min_occurrences = min_occurrences
  end

  def candidates
    @candidates ||= begin
      found = tally.filter_map do |key, data|
        next if known?(key)
        next if data[:districts].size < @min_districts || data[:occurrences] < @min_occurrences

        Candidate.new(name: data[:example], normalized_name: key,
                      district_count: data[:districts].size, occurrences: data[:occurrences])
      end

      found.sort_by { |candidate| [-candidate.occurrences, candidate.name] }
    end
  end

  # Replaces the computed entries wholesale, leaving manual ones alone. Wholesale
  # because a name that no longer qualifies should stop being blocked.
  def apply!
    BlockedLocationName.transaction do
      BlockedLocationName.computed.where.not(normalized_name: candidates.map(&:normalized_name)).delete_all

      candidates.each do |candidate|
        row = BlockedLocationName.find_or_initialize_by(normalized_name: candidate.normalized_name)
        next if row.persisted? && row.source == 'manual'

        row.assign_attributes(name: candidate.name, source: 'computed',
                              district_count: candidate.district_count, occurrences: candidate.occurrences)
        row.save!
      end
    end

    BlockedLocationName.reset!
    candidates.size
  end

  private

  # { key => { example:, occurrences:, districts: Set } }
  def tally
    @tally ||= {}.tap do |counts|
      Document.complete.in_batches(of: BATCH) do |batch|
        batch.pluck(:district_id, :extracted_locations).each do |district_id, names|
          names.to_a.each { |name| record(counts, district_id, name) }
        end
      end
    end
  end

  def record(counts, district_id, name)
    key = BlockedLocationName.key_for(name)
    return if key.blank?

    entry = counts[key] ||= { example: name, occurrences: 0, districts: Set.new }
    entry[:occurrences] += 1
    entry[:districts] << district_id
  end

  # The official registers are the authority: never blocklist something they
  # know. Also skips what is already blocked, so the list stays minimal.
  def known?(key)
    street_names.include?(key) || quarter_names.include?(key) || Location::BLOCKED_LOCATIONS.include?(key)
  end

  def street_names
    @street_names ||= Set.new(Street.distinct.pluck(:normalized_name))
  end

  def quarter_names
    @quarter_names ||= Set.new(Quarter.pluck(:name).map { |name| BlockedLocationName.key_for(name) })
  end
end
