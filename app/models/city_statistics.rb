# frozen_string_literal: true

# The figures behind the statistics page for all of Hamburg: every district's
# current legislation together. The Fraktionen are left out — they differ
# from one Bezirksversammlung to the next — and the map compares the Bezirke
# instead of Stadtteile.
class CityStatistics < DistrictStatistics
  def initialize
    super(nil)
  end

  def documents
    @documents ||= District.all.map { |district| Document.current_legislation(district) }.reduce(:or)
  end

  def meeting_count
    return 0 if start_date.nil?

    Meeting.complete.where(date: start_date..Date.current).count
  end

  # The Bezirke as ChoroplethAreas, with all their Drucksachen: everything a
  # Bezirksversammlung discusses concerns its Bezirk. The instances come from
  # District.by_number, which keeps them, and with them their simplified
  # outlines and label points.
  def district_areas
    counts = documents.group(:district_id).count

    District.by_order.map do |district|
      ChoroplethArea.new(shapes: [District.by_number(district.number)], count: counts.fetch(district.id, 0),
                         residents: Population::DISTRICT_RESIDENTS[district.name])
    end
  end
end
