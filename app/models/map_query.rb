# frozen_string_literal: true

# The Drucksachen the map shows (MapsController): those of a time range, of one
# topic or all, of one district or all of Hamburg — and the places they name.
#
# Pins and the counts per Bezirk and Stadtteil leave out Drucksachen that name
# more than MAX_PLACES places. A list of road works or of every playground in a
# Bezirk would bury the map under pins that say little about any one of them;
# such Drucksachen stay in the list beside the map.
class MapQuery
  # Time ranges by URL value; the first is the default.
  RANGES = {
    'aktuell' => 'Aktuell',
    'wahlperiode' => 'Aktuelle Wahlperiode',
    'letzte-wahlperiode' => 'Letzte Wahlperiode',
  }.freeze

  # What each range covers, said above the list beside the map.
  RANGE_HINTS = {
    'aktuell' => 'Was auf den Tagesordnungen der kommenden Sitzungen und der letzten drei Monate steht.',
    'wahlperiode' => 'Alles seit der Bezirksversammlungswahl 2024.',
    'letzte-wahlperiode' => 'Die Wahlperiode von 2019 bis 2024.',
  }.freeze

  # "Aktuell" reaches this far back, and forward to every meeting scheduled.
  # Three months are about three sessions of a Bezirksversammlung and its
  # committees, and still span the summer break.
  RECENT_MONTHS = 3

  MAX_PLACES = 20

  # Drucksachen a place's popup names before linking to the place's page.
  POPUP_DOCUMENTS = 5

  # The day of the 2019 Bezirksversammlung election. Drucksachen before a
  # district's first_legislation_number that reached a meeting since then make
  # up the last legislation. Move it on at the next election, together with the
  # districts' first_legislation_number.
  LAST_LEGISLATION_START = Date.new(2019, 5, 26)

  # The latest meeting a Drucksache reached, for ordering by it.
  LAST_MEETING = <<~SQL.squish.freeze
    (SELECT MAX(meetings.date) FROM agenda_items
     JOIN meetings ON meetings.id = agenda_items.meeting_id
     WHERE agenda_items.document_id = documents.id)
  SQL

  attr_reader :district, :range, :topic

  def self.range(value)
    RANGES.key?(value) ? value : RANGES.keys.first
  end

  def initialize(district: nil, range: nil, topic: nil)
    @district = district
    @range = self.class.range(range)
    @topic = topic
  end

  def documents
    @documents ||= begin
      scope = in_range.complete
      scope = scope.with_topics([topic.key]) if topic
      scope
    end
  end

  # Every place of the range, for the pins: [location id, latitude, longitude,
  # number of Drucksachen, whether one of them is still to be discussed].
  def places
    upcoming = "BOOL_OR(document_locations.document_id IN (#{discussed_since(Date.current).to_sql}))"

    pinned_links.group('locations.id')
                .pluck('locations.id', 'locations.latitude', 'locations.longitude',
                       Arel.sql('COUNT(DISTINCT document_locations.document_id)'), Arel.sql(upcoming))
                .map { |id, lat, lng, count, coming| [id, lat.round(5), lng.round(5), count, coming ? 1 : 0] }
  end

  # How many pinned Drucksachen name a place in each Stadtteil and Bezirk:
  # { quarters: { name => count }, districts: { number => count } }. A
  # Drucksache counts once per area, however many of its places lie there.
  def area_counts
    pinned = DocumentLocation.from(pinned_links.select(:document_id, Arel.sql('unnest(locations.quarters) AS quarter')), :pinned)
                             .distinct

    {
      quarters: pinned.group('pinned.quarter').count('pinned.document_id'),
      districts: pinned.joins('JOIN quarters ON quarters.name = pinned.quarter')
                       .group('quarters.district_number').count('pinned.document_id'),
    }
  end

  # How much of the range the map can show: all its Drucksachen, those naming a
  # place on the map, and those pinned.
  def counts
    {
      documents: documents.count,
      placed: links.distinct.count(:document_id),
      pinned: pinned_links.distinct.count(:document_id),
    }
  end

  # The Drucksachen naming a place inside the box, latest meeting first. All of
  # them, including those with too many places for a pin.
  def documents_within(south:, west:, north:, east:)
    inside = links.where(locations: { latitude: south..north, longitude: west..east })

    by_last_meeting(documents.where(id: inside.select(:document_id)))
  end

  # The pinned Drucksachen naming the location, latest meeting first.
  def documents_at(location)
    by_last_meeting(documents.where(id: pinned_links.where(location_id: location.id).select(:document_id)))
  end

  private

  def in_range
    case range
    when 'wahlperiode' then per_district { |district| Document.current_legislation(district) }
    when 'letzte-wahlperiode' then per_district { |district| last_legislation(district) }
    else
      scope = Document.where(id: discussed_since(RECENT_MONTHS.months.ago.to_date))
      district ? scope.where(district:) : scope
    end
  end

  # The legislations are counted per district: each numbers its own.
  def per_district(&)
    (district ? [district] : District.all).map(&).reduce(:or)
  end

  def last_legislation(district)
    Document.where(district:)
            .where.not(id: Document.current_legislation(district).select(:id))
            .where(id: discussed_since(LAST_LEGISLATION_START))
  end

  def discussed_since(date)
    AgendaItem.joins(:meeting).where(meetings: { date: date.. }).select(:document_id)
  end

  # The links to the places of the range that the map can show: those with a
  # position.
  def links
    DocumentLocation.joins(:location).where(document_id: documents.select(:id)).where.not(locations: { latitude: nil })
  end

  def pinned_links
    few = links.group(:document_id).having('COUNT(*) <= ?', MAX_PLACES).select(:document_id)

    links.where(document_id: few)
  end

  def by_last_meeting(scope)
    scope.order(Arel.sql("#{LAST_MEETING} DESC NULLS LAST, documents.id DESC"))
  end
end
