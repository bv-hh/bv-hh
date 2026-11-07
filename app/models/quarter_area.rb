# frozen_string_literal: true

# A Stadtteil, or two that the population figures count together (see
# QuarterPopulation), with the number of Drucksachen concerning it and its
# residents.
class QuarterArea < Data.define(:quarters, :count, :residents)
  # Below this the rate says more about chance than about the Stadtteil: a
  # harbour area with a few hundred residents and a dozen Drucksachen would
  # top every district.
  MIN_RESIDENTS = 2_000
  # Drucksachen per this many residents.
  PER_RESIDENTS = 10_000

  # "Waltershof und Finkenwerder"
  def name
    quarters.map(&:name).to_sentence
  end

  def combined?
    quarters.size > 1
  end

  # Drucksachen per PER_RESIDENTS residents, or nil where there are too few.
  def rate
    return nil if residents.to_i < MIN_RESIDENTS

    count * PER_RESIDENTS.fdiv(residents)
  end
end
