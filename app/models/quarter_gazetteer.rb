# frozen_string_literal: true

# Finds the 104 official Stadtteile inside free text, the way StreetGazetteer
# finds streets: whole-word windows over a memoized index, no model.
#
# The NER model is the only thing that finds Stadtteile today, and it misses
# the forms Drucksachen write most: the genitive ("Eppendorfs") and the
# compound a regional committee is named after
# ("Barmbek-Uhlenhorst-Hohenfelde-Dulsberg"). Tokenizing splits the compound on
# its hyphens, so each Stadtteil in it is found on its own.
#
# Used by NerComparison to measure whether it can replace the model.
class QuarterGazetteer
  # Spellings the register never uses but documents do, generated for every
  # name. "St. Georg" is the register's own form; "Sankt Georg" is not.
  VARIANTS = [
    [/ß/, 'ss'],
    [/\Ast /, 'sankt '],
  ].freeze

  # Four Stadtteile share their name with the district around them. After one
  # of these words the name is the district — "Bezirksamt Wandsbek" is the
  # author of the Drucksache, not a place it is about.
  DISTRICT_WORDS = %w[bezirk bezirks bezirksamt bezirksamts bezirksversammlung bezirksverwaltung
                      bezirksamtsleitung].to_set.freeze

  class << self
    # The register's own spellings of every Stadtteil named in +text+.
    def match(text)
      return [] if text.blank?

      tokens = tokenize(text)
      names = []

      tokens.each_index do |i|
        next if i.positive? && DISTRICT_WORDS.include?(tokens[i - 1])

        (1..max_words).each do |length|
          break if i + length > tokens.size

          canonical = index[tokens[i, length].join(' ')]
          names << canonical if canonical
        end
      end

      names.uniq
    end

    # Drops the memoized index; call after (re)importing quarters.
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

    # normalized spelling => the register's own name.
    def build_index
      map = {}
      @max_words = 1

      Quarter.distinct.pluck(:name).each do |name|
        spellings(Street.normalize(name)).each do |spelling|
          map[spelling] ||= name
          word_count = spelling.count(' ') + 1
          @max_words = word_count if word_count > @max_words
        end
      end

      map
    end

    # The name, its variants, and the genitive of each ("Wandsbeks"). A name
    # ending in a sibilant has no separate genitive form in writing.
    def spellings(name)
      variants = VARIANTS.filter_map do |pattern, replacement|
        variant = name.sub(pattern, replacement)
        variant unless variant == name
      end

      forms = [name, *variants]
      genitives = forms.reject { |form| form.end_with?('s', 'x', 'z', 'ß') }.map { |form| "#{form}s" }

      (forms + genitives).uniq
    end

    def tokenize(text)
      text.downcase.scan(/[[:alnum:]]+/)
    end
  end
end
