# frozen_string_literal: true

# Finds the 104 official Stadtteile inside free text, the way StreetGazetteer
# finds streets: whole-word windows over a memoized index, no model.
#
# It also finds the forms Drucksachen write most, which the NER model it
# replaced missed: the genitive ("Eppendorfs") and the compound a regional
# committee is named after ("Barmbek-Uhlenhorst-Hohenfelde-Dulsberg").
# Tokenizing splits the compound on its hyphens, so each Stadtteil in it is
# found on its own.
class QuarterGazetteer
  # Spellings the register never uses but documents do, generated for every
  # name. "St. Georg" is the register's own form; "Sankt Georg" is not.
  VARIANTS = [
    [/ß/, 'ss'],
    [/\Ast /, 'sankt '],
  ].freeze

  # Four Stadtteile share their name with the district around them. After a
  # word starting like this the name is the district — "des Bezirksamtes
  # Wandsbek" is the author of the Drucksache, not a place it is about.
  DISTRICT_PREFIX = 'bezirk'

  # "Herr Horn (CDU)" is a member of the Bezirksversammlung. Tokenizing drops
  # the parentheses, so the party follows the name directly.
  PERSON_BEFORE = %w[herr herrn frau dr].to_set.freeze
  PERSON_AFTER = %w[cdu spd grüne grünen fdp linke afd volt].to_set.freeze

  class << self
    # The register's own spellings of every Stadtteil named in +text+.
    #
    # Not where the name is part of a longer street name: "Hinterm Horn" is a
    # street in Bergedorf and "Wandsbek Markt" one in Wandsbek, and neither is
    # about the Stadtteil.
    def match(text)
      return [] if text.blank?

      tokens = tokenize(text)
      streets = StreetGazetteer.spans(tokens)
      names = []

      tokens.each_index do |i|
        next if district_or_person?(tokens, i)

        (1..max_words).each do |length|
          break if i + length > tokens.size

          canonical = index[tokens[i, length].join(' ')]
          names << canonical if canonical && !inside_street?(streets, i, length)
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

    def district_or_person?(tokens, position)
      before = position.positive? ? tokens[position - 1] : nil

      before&.start_with?(DISTRICT_PREFIX) || PERSON_BEFORE.include?(before) ||
        PERSON_AFTER.include?(tokens[position + 1])
    end

    # Whether a street match covers the window and is longer than it.
    def inside_street?(streets, start, length)
      streets.any? do |from, to|
        from <= start && start + length - 1 <= to && to - from + 1 > length
      end
    end

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
