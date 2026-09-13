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
  # Tokenizing drops the full stop, so "Heilwigstr." arrives here as
  # "heilwigstr" and needs no separate entry.
  VARIANTS = [
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

    # variant spelling => the register's own normalized name.
    def build_index
      map = {}
      @max_words = 1

      Street.distinct.pluck(:normalized_name).each do |name|
        next if name.blank? || name.length < MIN_LENGTH
        next if Location.blocked?(name)

        spellings(name).each do |spelling|
          next if spelling.length < MIN_LENGTH

          # First writer wins, so a variant can never shadow a street that
          # actually carries that spelling.
          map[spelling] ||= name
          word_count = spelling.count(' ') + 1
          @max_words = word_count if word_count > @max_words
        end
      end

      map
    end

    def spellings(name)
      variants = VARIANTS.filter_map do |pattern, replacement|
        variant = name.sub(pattern, replacement)
        variant unless variant == name
      end

      [name, *variants].uniq
    end

    def tokenize(text)
      text.downcase.scan(/[[:alnum:]]+/)
    end
  end
end
