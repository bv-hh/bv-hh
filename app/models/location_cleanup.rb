# frozen_string_literal: true

# Finds Locations the current resolution path would not produce.
#
# The Google era left three kinds of debris behind, and hand-enumerating them
# turned out to be the wrong approach. "Stadtpark" was not six duplicates of one
# park: it was six different places Google offered for one word — Spielplatz im
# Stadtpark, Sandplatz Stadtpark, Große Wiese im Stadtpark, Liebesinsel,
# Ententeich. "Stadt-Viertel" was six sub-areas across two districts. Stadtteil
# names were geocoded to a point before that stopped being allowed.
#
# So the rule is not a list of categories but a question asked of each row:
# would the registers produce this location today? Everything that answers no is
# debris, whatever kind it is — and the rule stays true as the registers change,
# instead of describing one particular mess.
#
# Dry run by default; the rake task writes only when told to.
class LocationCleanup
  Stale = Struct.new(:location, :reason, :documents, keyword_init: true)

  def stale
    @stale ||= Location.includes(:district, documents: :district).filter_map do |location|
      reason = staleness(location)
      next if reason.blank?

      Stale.new(location: location, reason: reason, documents: location.document_locations.count)
    end
  end

  # Destroying a location takes its document_locations with it, which is the
  # point: the documents stop claiming a place that is not one.
  def apply!
    stale.each { |entry| entry.location.destroy }.size
  end

  private

  # Why this row would not be created today, or nil when it still would be.
  def staleness(location)
    districts = districts_for(location)
    return 'no district' if districts.empty?

    name = location.extracted_name
    return 'blocked name' if Location.blocked?(name)
    return 'Stadtteil, recorded on the document instead' if Quarter.canonical_names([name]).any?

    return nil if districts.any? { |district| expected_names(name, district).include?(location.name) }

    'no register answers with this place'
  end

  # Every district that could have created this row. Location.normalized has no
  # district filter, so one row is shared by every district that mentions the
  # name and its own district_id is merely whichever got there first — asking
  # only that one would condemn a Hamburg-Nord street held by a Hamburg-Mitte
  # row.
  def districts_for(location)
    ([location.district] + location.documents.map(&:district)).compact.uniq
  end

  # The names the registers would answer with, in the resolution order of
  # Location.determine_locations — without creating anything. Stations are
  # included because a station row records the station's own name as the
  # extracted name.
  def expected_names(name, district)
    names = Street.for(name, district).map(&:name)
    names = Poi.for(name, district).map(&:name) if names.empty?
    names = Street.fuzzy_for(name, district).map(&:name) if names.empty?

    names + Poi.transit_for(name, district).map(&:name)
  end
end
