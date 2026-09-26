# frozen_string_literal: true

# Whether the corpus uses a word all over the city, or mostly in the districts
# a place of that name is in — the breadth signal of LocationBlocklist, made
# relative.
#
# "Feuerwehr" is a playground in OSM and a word in every district. "Meiendorf"
# is mentioned by three districts too, but most of the documents naming it are
# Wandsbek's, where it is. The gazetteers ask this of single-word names, which
# are the ones that double as ordinary words.
#
# One query per word, answered by the full-text index behind Document.search.
# The German stemmer folds "Horner" into "horn", so an adjective formed from a
# place counts as a mention of it — which is what it usually is.
class CorpusBreadth
  # Fewer districts than this is never citywide.
  MIN_DISTRICTS = LocationBlocklist::MIN_DISTRICTS
  # The share of mentioning documents the home districts must hold.
  HOME_SHARE = 0.5

  class << self
    def citywide?(word, home_numbers)
      counts = Document.where("#{Document::SEARCH_VECTOR} @@ plainto_tsquery('german', ?)", word)
                       .group(:district_id).count
      return false if counts.size < MIN_DISTRICTS

      home = counts.sum { |district_id, count| home_numbers.include?(district_numbers[district_id]) ? count : 0 }
      home < HOME_SHARE * counts.values.sum
    end

    def reset!
      @district_numbers = nil
    end

    private

    def district_numbers
      @district_numbers ||= District.all.to_h { |district| [district.id, district.number] }
    end
  end
end
