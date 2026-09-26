# frozen_string_literal: true

# Measures what location extraction would lose, and gain, without the NER
# model.
#
# The model's own contribution is narrow: StreetGazetteer finds the streets,
# and the model is left proposing Stadtteile, POI names and the damaged
# spellings the trigram match repairs — alongside every acronym and noun the
# blocklist has to catch. The alternative is a gazetteer for each of those
# registers: QuarterGazetteer and PoiGazetteer next to StreetGazetteer.
#
# A sample of documents is extracted both ways, and each side is resolved the
# way Document#assign_extracted_locations! and #extracted_quarters would do it.
# The report compares what each document ends up with — its Stadtteile and the
# places it would be pinned to — not the raw names, since a name no register
# resolves makes no difference to the site.
#
# Read-only: resolution mirrors Location.determine_locations without
# build_location, so no Location is created and no document is changed.
# Driven by `rake locations:compare_extraction`.
class NerComparison
  SAMPLE = 500
  EXAMPLES = 25

  Result = Struct.new(:quarters, :places, :noise, keyword_init: true) do
    # Whether this side has a Stadtteil or a place the other lacks.
    def beyond?(other)
      (quarters.keys - other.quarters.keys).any? || (places.keys - other.places.keys).any?
    end
  end

  attr_reader :documents, :names, :noise, :quarters, :places, :lost_documents, :seconds

  # +ner+ answers the model's names for a text; injectable so tests need not
  # load the 328 MB model.
  def initialize(sample: SAMPLE, ner: ->(document, text) { document.ner_locations(text) })
    @sample = sample
    @ner = ner
    @documents = 0
    @names = { current: 0, gazetteer: 0 }
    @noise = { current: 0, gazetteer: 0 }
    @quarters = comparison
    @places = comparison
    @lost_documents = 0
    @seconds = { ner: 0.0, gazetteers: 0.0 }
    @resolved = {}
  end

  def run
    Document.complete.where.not(full_text: [nil, '']).order(Arel.sql('random()')).limit(@sample)
            .includes(:district, :committees).each { |document| compare(document) }

    self
  end

  private

  def comparison
    { both: 0, lost: 0, gained: 0, lost_examples: [], gained_examples: [] }
  end

  def compare(document)
    text = document.extractable_text
    return if text.blank?

    @documents += 1
    current = resolve(document, extract(:current, document, text))
    gazetteer = resolve(document, extract(:gazetteer, document, text))
    @noise[:current] += current.noise
    @noise[:gazetteer] += gazetteer.noise

    tally(@quarters, document, current.quarters, gazetteer.quarters)
    tally(@places, document, current.places, gazetteer.places)
    @lost_documents += 1 if current.beyond?(gazetteer)
  end

  # What Document#extract_locations! would store as extracted_locations.
  def extract(side, document, text)
    found = side == :current ? timed(:ner) { @ner.call(document, text) } : timed(:gazetteers) { gazetteers(text) }

    # The model reports "Fuhlsbütteler Straße" where the gazetteer reports
    # "fuhlsbütteler straße": one name, counted once.
    names = (StreetGazetteer.match(text) + found).uniq { |name| Location.normalize(name) }
    @names[side] += names.size
    names
  end

  def gazetteers(text)
    QuarterGazetteer.match(text) + PoiGazetteer.match(text)
  end

  # Stadtteile as #extracted_quarters records them, and places as
  # #assign_extracted_locations! would link them, each keyed by what makes it
  # the same answer on both sides. Values are the names that produced them.
  def resolve(document, names)
    district = document.district
    local = names.reject { |name| document.from_local_committee?(name) }

    quarters = Quarter.canonical_names(local).index_with { |name| name }
    places = {}
    noise = 0

    local.each do |name|
      keys = resolved(name, district)
      noise += 1 if keys.empty? && Quarter.canonical_names([name]).empty?
      keys.each { |key, label| places[key] ||= "#{name} → #{label}" }
    end

    Result.new(quarters:, places:, noise:)
  end

  def tally(counts, document, current, gazetteer)
    counts[:both] += (current.keys & gazetteer.keys).size

    (current.keys - gazetteer.keys).each do |key|
      counts[:lost] += 1
      example(counts[:lost_examples], document, current[key])
    end

    (gazetteer.keys - current.keys).each do |key|
      counts[:gained] += 1
      example(counts[:gained_examples], document, gazetteer[key])
    end
  end

  def example(list, document, label)
    list << "#{document.id}: #{label}" if list.size < EXAMPLES
  end

  # [place key, register name] pairs for +name+, memoized: the same names
  # recur across the sample.
  def resolved(name, district)
    @resolved[[Location.normalize(name), district.id]] ||= places_for(name, district)
  end

  # Location.determine_locations without creating anything. The reuse of an
  # existing row is left out: every such row is reproducible from the
  # registers now (see PoiCoverage#reproducible_locations).
  def places_for(name, district)
    return [] if Location.blocked?(name)
    return [] if Quarter.canonical_names([name]).any?

    streets(Street.for(name, district)).presence ||
      pois(Poi.for(name, district)).presence ||
      streets(Street.near_for(name, district)).presence ||
      pois(Poi.near_for(name, district)).presence ||
      streets(Street.fuzzy_for(name, district))
  end

  def streets(scope) = scope.map { |street| ["gazetteer:#{street.street_key}", street.name] }
  def pois(scope) = scope.map { |poi| [poi.place_key, poi.name] }

  def timed(bucket)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
  ensure
    @seconds[bucket] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end
end
