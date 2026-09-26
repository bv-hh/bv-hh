# frozen_string_literal: true

# Finds official Hamburg street names (from the Street gazetteer) inside free
# text. Instead of NER, it looks up every 1..N word window of the text against
# the set of known street names — deterministic, morphology-independent and
# fast. The name/word index is built once per process and memoized.
class StreetGazetteer
  MIN_LENGTH = 4

  # Spellings the register never uses but documents do. Each maps a variant of a
  # normalized street name back to the register's own spelling, so a match on
  # "heilwigstr" still reports "heilwigstraße" and Street.for can find it.
  #
  # Applied in order, each to every spelling the ones before it produced, so
  # "Ohlsdorfer Straße" is also found as "Ohlsdorferstr".
  #
  # Tokenizing drops the full stop, so "Heilwigstr." arrives here as
  # "heilwigstr" and needs no separate entry.
  VARIANTS = [
    # "Ohlsdorferstraße": the adjective glued to the street word.
    [/er (straße|weg|platz|allee|chaussee|damm|brücke|ring)\z/, 'er\1'],
    # "Poppenbütteler Landstraße" where the register drops the e, and the
    # other way round: the register writes both.
    [/üttler\b/, 'ütteler'],
    [/ütteler\b/, 'üttler'],
    # The genitive, "des Sülldorfer Brookswegs", "des Parnass-Platzes".
    [/(weg|damm|markt|ring)\z/, '\1s'],
    [/platz\z/, 'platzes'],
    # "Harburger Schlossstraße": ss for ß in the name, ß kept in the suffix.
    [/ß(?!e\b)/, 'ss'],
    [/straße\b/, 'strasse'],
    [/straße\b/, 'str'],
    [/strasse\b/, 'str'],
    [/platz\b/, 'pl'],
  ].freeze

  class << self
    # Returns the distinct normalized street names that occur in +text+.
    def match(text)
      return [] if text.blank?

      tokens = tokenize(text)
      names = []

      tokens.each_index do |i|
        (1..max_words).each do |length|
          break if i + length > tokens.size

          canonical = index[tokens[i, length].join(' ')]
          names << canonical if canonical
        end
      end

      names.uniq
    end

    # The register's own spelling for a normalized name, or nil when the
    # register has never heard of it in any spelling. Street.for resolves
    # through this so that a name extracted as "Krausestrasse" reaches the
    # register's "Krausestraße" at assignment time, not only at extraction.
    def canonical(name)
      index[name]
    end

    # Drops the memoized index; call after (re)importing streets.
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

    # variant spelling => the register's own normalized name. Every register
    # name goes in before any variant, so a variant can never shadow a street
    # that actually carries that spelling.
    def build_index
      names = Street.distinct.pluck(:normalized_name).select do |name|
        name.present? && name.length >= MIN_LENGTH && !Location.blocked?(name)
      end

      map = names.index_with { |name| name }
      names.each do |name|
        spellings(name).each { |spelling| map[spelling] ||= name if spelling.length >= MIN_LENGTH }
      end

      @max_words = map.keys.map { |spelling| spelling.count(' ') + 1 }.max || 1
      map
    end

    def spellings(name)
      VARIANTS.reduce([name]) do |forms, (pattern, replacement)|
        forms + forms.filter_map do |form|
          variant = form.gsub(pattern, replacement)
          variant unless variant == form
        end
      end.uniq
    end

    def tokenize(text)
      text.downcase.scan(/[[:alnum:]]+/)
    end
  end
end
