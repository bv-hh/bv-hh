# frozen_string_literal: true

# Moves the Locations geocoded by Google onto the local registers.
#
# Resolution reuses a district's existing Location of a name before it asks a
# register (Location.determine_locations), and LocationCleanup keeps every row
# a register would still produce. So a street Google once placed kept Google's
# point and place id after the switch to the registers: Stockflethweg sits 75 m
# from where the street register puts it, and a search for the street circled
# the register's point beside the map's pin.
#
# Each such row takes the point, place id and address of the entry its name
# resolves to in its own district — the street first, then a named place, in
# the order determine_locations asks. Of several entries of one name, the
# nearest. The row itself stays, and with it every link to a Drucksache.
# A name no register knows in the district is left alone.
#
# Dry run by default; the rake task writes only when told to.
class LocationRebase
  Move = Struct.new(:location, :latitude, :longitude, :place_id, :formatted_address, :metres, keyword_init: true)

  # The ids the registers give; everything else came from Google.
  REGISTER_IDS = ['gazetteer:%', 'osm:%'].freeze

  def self.legacy
    Location.where.not(Location.sanitize_sql_array(['place_id LIKE ? OR place_id LIKE ?', *REGISTER_IDS]))
            .or(Location.where(place_id: nil))
  end

  def moves
    @moves ||= self.class.legacy.includes(:district).filter_map { |location| move_for(location) }
  end

  # Locations left as they are: no register knows their name in the district.
  def unmatched
    self.class.legacy.count - moves.size
  end

  def apply!
    moves.each do |move|
      location = move.location
      location.update!(latitude: move.latitude, longitude: move.longitude, place_id: move.place_id,
                       formatted_address: move.formatted_address,
                       **Location.place_attributes(location.name, move.latitude, move.longitude, location.district))
    end.size
  end

  private

  def move_for(location)
    return if location.district.blank?

    candidates = streets(location).presence || pois(location)
    target = candidates.min_by { |candidate| metres(location, candidate) || 0 }
    return if target.blank?

    Move.new(location:, **target, metres: metres(location, target)&.round)
  end

  def streets(location)
    Street.for(location.name, location.district).where.not(latitude: nil).map do |street|
      { latitude: street.latitude, longitude: street.longitude, place_id: "gazetteer:#{street.street_key}",
        formatted_address: street.formatted_address }
    end
  end

  def pois(location)
    Poi.for(location.name, location.district).map do |poi|
      { latitude: poi.latitude, longitude: poi.longitude, place_id: poi.place_key, formatted_address: poi.formatted_address }
    end
  end

  # Straight-line distance, near enough at Hamburg's scale. nil for a row
  # without a point, which any register entry improves on.
  def metres(location, target)
    return if location.latitude.blank? || location.longitude.blank?

    north = (target[:latitude] - location.latitude) * 111_320
    east = (target[:longitude] - location.longitude) * 111_320 * Math.cos(location.latitude * Math::PI / 180)
    Math.hypot(north, east)
  end
end
