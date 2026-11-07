# frozen_string_literal: true

# What a Choropleth shades: a Stadtteil, two Stadtteile the population
# figures count together, or a Bezirk (shapes, each with a name and a
# PolygonShape), with its Drucksachen and residents.
class ChoroplethArea < Data.define(:shapes, :count, :residents)
  # Below this the rate says more about chance than about the place: a
  # harbour area with a few hundred residents and a dozen Drucksachen would
  # top every district.
  MIN_RESIDENTS = 2_000
  # Drucksachen per this many residents.
  PER_RESIDENTS = 10_000

  # "Waltershof und Finkenwerder"
  def name
    shapes.map(&:name).to_sentence
  end

  def combined?
    shapes.size > 1
  end

  # Drucksachen per PER_RESIDENTS residents, or nil where there are too few.
  def rate
    return nil if residents.to_i < MIN_RESIDENTS

    count * PER_RESIDENTS.fdiv(residents)
  end
end
