# frozen_string_literal: true

# Finds official Hamburg street names (from the Street gazetteer) inside free
# text. Instead of NER, it looks up every 1..N word window of the text against
# the set of known street names — deterministic, morphology-independent and
# fast. The name/word index is built once per process and memoized.
class StreetGazetteer
  MIN_LENGTH = 4

  class << self
    # Returns the distinct normalized street names that occur in +text+.
    def match(text)
      return [] if text.blank?

      tokens = tokenize(text)
      names = []

      tokens.each_index do |i|
        (1..max_words).each do |length|
          break if i + length > tokens.size

          candidate = tokens[i, length].join(' ')
          names << candidate if index.include?(candidate)
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

    def build_index
      set = Set.new
      @max_words = 1

      Street.distinct.pluck(:normalized_name).each do |name|
        next if name.blank? || name.length < MIN_LENGTH
        next if Location.blocked?(name)

        set << name
        word_count = name.count(' ') + 1
        @max_words = word_count if word_count > @max_words
      end

      set
    end

    def tokenize(text)
      text.downcase.scan(/[[:alnum:]]+/)
    end
  end
end
