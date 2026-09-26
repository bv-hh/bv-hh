# frozen_string_literal: true

# Finds pinnable OpenStreetMap feature names inside free text — parks,
# playgrounds, schools, cemeteries — the way StreetGazetteer finds streets.
#
# Only pinnable POIs are indexed: a generic name ("Spielplatz") would match
# everywhere and resolve nowhere, and a station is reachable only through
# TransitGazetteer. What is reported is the matched spelling, the register's
# own name or one of its aliases, which is exactly what Poi.for looks up.
#
# Matching every word of every document is a wide net, so two kinds of name are
# left out that Poi.for would still resolve:
#
# * Categories whose names are titles or people rather than places. An artwork
#   is called "Zwei", "Prüfung" or "Fischer"; a memorial or a tomb carries a
#   person's name. A Bezirksamt is named in nearly every Drucksache as its
#   author, not its subject.
# * Single-word names the corpus uses all over the city (see CorpusBreadth).
#   "Feuerwehr" is a playground in OSM; "Jahnkampfbahn" is written about in one
#   district only.
class PoiGazetteer
  EXCLUDED_CATEGORIES = %w[tourism=artwork historic=memorial historic=tomb historic=boundary_stone
                           historic=milestone historic=stone historic=wayside_shrine amenity=townhall].freeze

  class << self
    # The distinct normalized POI spellings that occur in +text+.
    def match(text)
      return [] if text.blank?

      tokens = tokenize(text)
      names = []

      tokens.each_index do |i|
        (1..max_words).each do |length|
          break if i + length > tokens.size

          spelling = tokens[i, length].join(' ')
          names << spelling if index.include?(spelling)
        end
      end

      names.uniq
    end

    # Drops the memoized index; call after (re)importing POIs.
    def reset!
      @index = nil
      @max_words = nil
    end

    private

    def index
      @index ||= build_index
    end

    def max_words
      index
      @max_words
    end

    def build_index
      homes = candidate_spellings
      ordinary = homes.select { |spelling, districts| spelling.exclude?(' ') && CorpusBreadth.citywide?(spelling, districts) }
      spellings = homes.keys.to_set - ordinary.keys
      @max_words = spellings.map { |spelling| spelling.count(' ') + 1 }.max || 1

      spellings
    end

    # spelling => the district numbers of the POIs carrying it.
    def candidate_spellings
      homes = Hash.new { |hash, key| hash[key] = Set.new }

      Poi.pinnable.where.not(category: EXCLUDED_CATEGORIES).pluck(:normalized_name, :aliases, :district_number)
         .each do |normalized, aliases, number|
        [normalized, *aliases].each do |spelling|
          next if spelling.blank? || spelling.length < Poi::MIN_LENGTH || Location.blocked?(spelling)

          homes[spelling] << number
        end
      end

      homes
    end

    # The same tokenization as StreetGazetteer, so a name indexed by
    # Poi.normalize is found by the same word boundaries.
    def tokenize(text)
      text.downcase.scan(/[[:alnum:]]+/)
    end
  end
end
