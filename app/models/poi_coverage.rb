# frozen_string_literal: true

# Measures how much of the corpus the local POI gazetteer answers, and how much
# of it only Google answers today.
#
# Every name extraction has ever produced is replayed through the resolution
# order of Location.determine_locations and reported by the step that would
# answer it. The bucket that decides whether Google can be removed outright is
# "would reach Google": what the POI gazetteer answers there is what Google
# stops being asked for, and what stays unresolved is the price of removing it.
#
# Read-only: it creates and changes nothing. Driven by `rake pois:coverage`.
class PoiCoverage
  BUCKETS = %i[blocked quarter street poi fuzzy poi_generic unresolved].freeze
  # The buckets the street register cannot answer exactly — what used to reach
  # Google Places, and what the local sources now have to cover between them.
  BEYOND_REGISTER = %i[poi fuzzy poi_generic unresolved].freeze
  BATCH = 500
  EXAMPLES = 20
  # Station references are found in raw text, not among the extracted names, so
  # they are counted over a sample rather than over the whole corpus.
  TRANSIT_SAMPLE = 400

  attr_reader :counts, :examples

  def initialize
    @counts = BUCKETS.index_with { |_bucket| { instances: 0, names: Set.new } }
    @examples = BUCKETS.index_with { |_bucket| [] }
  end

  def run
    Document.complete.in_batches(of: BATCH) do |batch|
      batch.pluck(:district_id, :extracted_locations).each do |district_id, names|
        district = districts[district_id]
        next if district.blank?

        names.to_a.each { |name| record(name, district) }
      end
    end

    self
  end

  def total = counts.values.sum { |data| data[:instances] }
  def google = BEYOND_REGISTER.sum { |bucket| counts[bucket][:instances] }
  def answered = counts[:poi][:instances] + counts[:fuzzy][:instances]
  def unresolved = counts[:unresolved][:instances]

  def share(instances) = percentage(instances, total)
  def google_share(instances) = percentage(instances, google)

  # Locations that exist because Google answered — the rows that would change
  # source, or lose their basis, if it went away.
  def google_locations
    @google_locations ||= Location.where.not(place_id: nil)
                                  .where.not("place_id LIKE 'gazetteer:%'")
                                  .where.not("place_id LIKE 'osm:%'")
  end

  def reproducible_locations
    google_locations.count { |location| resolvable?(location.extracted_name, districts[location.district_id]) }
  end

  # Documents in a sample whose text names a station behind a transit prefix —
  # the share the new transit path would newly resolve. Returns [documents with
  # a station, documents sampled, example station names].
  def transit_sample(limit: TRANSIT_SAMPLE)
    found = 0
    stations = Set.new
    documents = Document.complete.order(:id).limit(limit)

    documents.each do |document|
      names = TransitGazetteer.match(document.extractable_text)
      next if names.empty?

      found += 1
      stations.merge(names)
    end

    [found, documents.size, stations.to_a.sort]
  end

  private

  def record(name, district)
    bucket = classify(name, district)
    data = counts[bucket]
    data[:instances] += 1
    data[:names] << Poi.normalize(name)
    examples[bucket] << name if examples[bucket].size < EXAMPLES
  end

  # The resolution order of Location.determine_locations, with the POI gazetteer
  # in the position Google holds today.
  def classify(name, district)
    return :blocked if Location.blocked?(name)
    return :quarter if Quarter.canonical_names([name]).any?
    return :street if street?(name, district)

    entry = pois[[Poi.normalize(name), district.number]]
    return :poi if entry[:pinnable]
    return :fuzzy if Street.fuzzy_for(name, district).exists?
    return :poi_generic if entry[:generic]

    :unresolved
  end

  def resolvable?(name, district)
    return false if district.blank?

    street?(name, district) || pois[[Poi.normalize(name), district.number]][:pinnable] ||
      Street.fuzzy_for(name, district).exists?
  end

  # Street.canonical_name, not the plain normalization: the exact path resolves
  # spelling variants, so "krausestrasse" is a street register hit and must be
  # counted as one.
  def street?(name, district)
    streets[Street.canonical_name(name)].include?(district.number)
  end

  def percentage(instances, of)
    return '0.0%' if of.zero?

    format('%<share>.1f%%', share: 100.0 * instances / of)
  end

  def districts
    @districts ||= District.all.index_by(&:id)
  end

  # normalized street name => the district numbers it runs through.
  def streets
    @streets ||= begin
      index = Hash.new { |hash, key| hash[key] = Set.new }
      Street.distinct.pluck(:normalized_name, :district_numbers).each do |name, numbers|
        numbers.each { |number| index[name] << number }
      end
      index
    end
  end

  # [normalized name, district number] => whether a pinnable or a generic POI
  # carries it, under the register's own name or any alias. Transit POIs are
  # absent on purpose: a bare name never reaches them.
  def pois
    @pois ||= begin
      index = Hash.new { |hash, key| hash[key] = { pinnable: false, generic: false } }
      Poi.where(transit: false).pluck(:normalized_name, :aliases, :district_number, :generic)
         .each do |name, aliases, number, generic|
           [name, *aliases].each do |spelling|
             entry = index[[spelling, number]]
             generic ? entry[:generic] = true : entry[:pinnable] = true
           end
      end
      index
    end
  end
end
