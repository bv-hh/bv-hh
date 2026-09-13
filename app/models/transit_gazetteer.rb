# frozen_string_literal: true

# Finds Hamburg station names inside free text, but only where the text marks
# them as stations.
#
# Drucksachen write "U/S Barmbek", "S Ohlsdorf", "Haltestelle Sengelmannstraße",
# "Bahnhof Altona". The name on its own is almost never a station: "Barmbek" is
# a Stadtteil, "Sengelmannstraße" is a street, and both already resolve
# correctly on their own paths. The prefix is the entire signal, which is why
# stations are excluded from every plain-name lookup (Poi +transit+) and only
# reachable here.
#
# Built like StreetGazetteer: a memoized index over the local gazetteer, whole-
# word windows, no model and no network.
class TransitGazetteer
  # Tokenizing drops punctuation, so "U/S", "U-Bahn" and "S-Bahn-Haltestelle"
  # all arrive as separate tokens and are consumed as a run.
  PREFIXES = %w[u s ubahn sbahn akn haltestelle haltestellen
                bahnhof bahnhofs bf station].to_set.freeze

  # A prefix run longer than this is prose that happens to start with "S", not a
  # station reference.
  MAX_PREFIX_TOKENS = 3

  class << self
    # The register's own spellings of every station named in +text+ with a
    # transit prefix. Distinct, in order of first appearance.
    def match(text)
      return [] if text.blank?

      tokens = tokenize(text)
      names = []
      position = 0

      while position < tokens.size
        run = prefix_run(tokens, position)
        if run.zero?
          position += 1
          next
        end

        name = station_at(tokens, position + run)
        names << name if name
        position += run
      end

      names.uniq
    end

    # Drops the memoized index; call after (re)importing POIs.
    def reset!
      @index = nil
      @max_words = nil
    end

    private

    # How many consecutive prefix tokens start at +position+, 0 for none.
    def prefix_run(tokens, position)
      run = 0
      run += 1 while run < MAX_PREFIX_TOKENS && PREFIXES.include?(tokens[position + run])
      run
    end

    # The longest station name starting at +position+, or nil. Longest wins so
    # "S Hamburg Dammtor" does not stop at a station called "Hamburg".
    def station_at(tokens, position)
      max_words.downto(1) do |length|
        next if position + length > tokens.size

        canonical = index[tokens[position, length].join(' ')]
        return canonical if canonical
      end

      nil
    end

    def index
      @index ||= build_index
    end

    def max_words
      index
      @max_words
    end

    # normalized station name => the register's own spelling.
    def build_index
      map = {}
      @max_words = 1

      Poi.transit.distinct.pluck(:normalized_name, :name).each do |normalized, name|
        next if normalized.blank? || normalized.length < Poi::MIN_LENGTH
        # A station whose name is itself a prefix word ("Bahnhof") carries no
        # information and would match every prefix run in the corpus.
        next if PREFIXES.include?(normalized)

        map[normalized] ||= name
        word_count = normalized.count(' ') + 1
        @max_words = word_count if word_count > @max_words
      end

      map
    end

    # The same tokenization as StreetGazetteer, so a name indexed by
    # Poi.normalize (Street.normalize) is found by the same word boundaries.
    def tokenize(text)
      text.downcase.scan(/[[:alnum:]]+/)
    end
  end
end
