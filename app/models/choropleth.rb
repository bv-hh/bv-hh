# frozen_string_literal: true

# ChoroplethAreas shaded by Drucksachen per resident: a district's Stadtteile
# on the district and statistics pages, the Bezirke on the statistics page for
# all of Hamburg (choropleth_controller.js).
#
# The shades split the map's own rates into quantiles, so each map uses its
# whole ramp; they are not comparable from one map to the next.
class Choropleth
  # One sequential hue, light to dark. Areas without a rate get NO_RATE.
  RAMP = %w[#cde2fb #86b6ef #3987e5 #1c5cab #0d366b].freeze
  NO_RATE = '#d3d2ce'
  # From this step of RAMP on, a label on the area is set in white.
  LIGHT_TEXT_FROM = 2

  Shade = Data.define(:label, :color)

  attr_reader :areas

  def initialize(areas)
    @areas = areas
  end

  delegate :any?, to: :areas

  # Where each shade but the first begins, ascending: quantiles of the rates,
  # rounded to tens for a legend that reads easily. Fewer than RAMP.size - 1
  # when they coincide.
  def breaks
    @breaks ||= begin
      rates = areas.filter_map(&:rate).sort
      (1...RAMP.size).filter_map { |step| rates[step * rates.size / RAMP.size] }
                     .map { |rate| rate.round(-1) }.uniq
        .select { |lower| lower > rates.first.round }
    end
  end

  # One entry per shade in use, for the legend: "unter 120", "120–159", "ab 200".
  def shades
    bounds = [nil, *breaks, nil]
    colors.each_with_index.map do |color, index|
      Shade.new(label: range_label(bounds[index], bounds[index + 1]), color:)
    end
  end

  def no_rate?
    areas.any? { |area| area.rate.nil? }
  end

  # The areas with a rate first, highest first; then the rest by count.
  def ranked
    areas.sort_by { |area| [area.rate ? 0 : 1, -(area.rate || area.count), area.name] }
  end

  # One feature per shape for the map. url gives a shape's page.
  def features(url)
    areas.flat_map do |area|
      color = color(area)
      area.shapes.map do |shape|
        {
          name: shape.name,
          area: area.name,
          path: url.call(shape),
          count: area.count,
          rate: area.rate&.round,
          color:,
          light_text: RAMP.index(color).to_i >= LIGHT_TEXT_FROM,
          polygons: shape.simplified_geometry,
          label: shape.label_point,
        }
      end
    end
  end

  def color(area)
    area.rate ? colors[shade_index(area.rate)] : NO_RATE
  end

  private

  def range_label(lower, upper)
    return "unter #{upper}" if lower.nil?
    return "ab #{lower}" if upper.nil?

    "#{lower}–#{upper - 1}"
  end

  def shade_index(rate)
    breaks.count { |lower| rate.round >= lower }
  end

  # RAMP spread over the shades in use, so two shades are light and dark rather
  # than the two lightest.
  def colors
    @colors ||= begin
      count = breaks.size + 1
      count == 1 ? [RAMP[2]] : (0...count).map { |index| RAMP[(index * (RAMP.size - 1).fdiv(count - 1)).round] }
    end
  end
end
