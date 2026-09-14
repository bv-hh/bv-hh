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
  StaleLinks = Struct.new(:location, :district, :documents, keyword_init: true)
  Result = Struct.new(:locations, :links, :document_ids, keyword_init: true)

  def stale
    @stale ||= Location.includes(:district, documents: :district).filter_map do |location|
      reason = staleness(location)
      next if reason.blank?

      Stale.new(location: location, reason: reason, documents: location.document_locations.count)
    end
  end

  # Documents still claiming a location their own district would not resolve.
  #
  # Assignment is additive — it find_or_create_by!s a link and never removes
  # one — so the links a shared row collected while the reuse was cross-district
  # outlive the row's repair. Deleting the location cannot fix these: a street
  # that is real in one district keeps its row, and only the foreign documents
  # hanging off it are wrong.
  #
  # Asked once per (location, district) pair rather than once per link: there
  # are seven districts and hundreds of thousands of links.
  def stale_links
    @stale_links ||= link_pairs.filter_map do |(location_id, district_id), count|
      location = locations_by_id[location_id]
      district = districts_by_id[district_id]
      next if location.blank? || district.blank?
      next if expected_names(location.extracted_name, district).include?(location.name)

      StaleLinks.new(location: location, district: district, documents: count)
    end
  end

  # Destroying a location takes its document_locations with it, which is the
  # point: the documents stop claiming a place that is not one. Reports the
  # documents it touched, because they are exactly the ones that need assigning
  # again — see affected_document_ids.
  def apply!
    documents = affected_document_ids
    dropped = drop_stale_links!
    deleted = stale.each { |entry| entry.location.destroy }.size

    Result.new(locations: deleted, links: dropped, document_ids: documents)
  end

  # The documents losing a link here, collected before anything is deleted.
  #
  # Enough whenever the sweep is the only thing that changed: it only removes,
  # and the rows it deletes are rebuilt from these same documents under the
  # district that owns the street. Worth the bookkeeping, since this is a few
  # thousand documents where re-running extraction is 58000, each an NER pass
  # over a PDF's text.
  #
  # NOT enough after a change that lets a name resolve where it did not before —
  # a widened threshold in Street.near_for, a register import. A document the
  # sweep never touches can gain a location then, and only locations:reassign
  # over the corpus finds it.
  def affected_document_ids
    @affected_document_ids ||= begin
      ids = DocumentLocation.where(location: stale.map(&:location)).pluck(:document_id)

      ids += stale_links.flat_map do |entry|
        DocumentLocation.where(location: entry.location)
                        .joins(:document).where(documents: { district_id: entry.district.id })
                        .pluck(:document_id)
      end

      ids.uniq
    end
  end

  private

  # Links belonging to a location that is going away anyway are left to the
  # cascade; counting them twice would only inflate the report.
  def drop_stale_links!
    doomed = stale.to_set { |entry| entry.location.id }

    stale_links.reject { |entry| doomed.include?(entry.location.id) }.sum do |entry|
      DocumentLocation.where(location: entry.location)
                      .where(document: Document.where(district: entry.district)).delete_all
    end
  end

  def link_pairs
    @link_pairs ||= DocumentLocation.joins(:document).group(:location_id, 'documents.district_id').count
  end

  def locations_by_id
    @locations_by_id ||= Location.includes(:district).index_by(&:id)
  end

  def districts_by_id
    @districts_by_id ||= District.all.index_by(&:id)
  end

  # Why this row would not be created today, or nil when it still would be.
  #
  # Asked of the row's own district alone. It used to be asked of every district
  # holding a document, because reuse was cross-district and a row's district_id
  # was merely whichever got there first — but that is the behaviour that let
  # one word pin seven districts, and resolution no longer works that way. A row
  # the register does not place in its own district is now debris; reanalysis
  # rebuilds it under the district that does own the street.
  def staleness(location)
    district = location.district
    return 'no district' if district.blank?

    name = location.extracted_name
    return 'blocked name' if Location.blocked?(name)
    return 'Stadtteil, recorded on the document instead' if Quarter.canonical_names([name]).any?
    return nil if expected_names(name, district).include?(location.name)

    elsewhere = districts_answering(location)
    return 'no register answers with this place' if elsewhere.empty?

    "not in #{district.name}, the register places it in #{elsewhere.join(' and ')}"
  end

  # The districts whose registers do answer with this place. A row that one of
  # them owns is not debris but misfiled: its district_id records which district
  # happened to write the name first, back when a row was shared by all of them.
  # Deleting it is still right — reassignment rebuilds it under the district
  # that owns the street, from the same documents — but the dry run has to say
  # so, because "no register answers with this place" reads like the register
  # has never heard of Kollaustraße.
  def districts_answering(location)
    districts_by_id.each_value.reject { |district| district == location.district }
                   .select { |district| expected_names(location.extracted_name, district).include?(location.name) }
                   .map(&:name)
  end

  # The names the registers would answer with, in the resolution order of
  # Location.determine_locations — without creating anything. Stations are
  # included because a station row records the station's own name as the
  # extracted name.
  def expected_names(name, district)
    names = Street.for(name, district).map(&:name)
    names = Poi.for(name, district).map(&:name) if names.empty?
    names = near_names(name, district) if names.empty?
    names = Street.fuzzy_for(name, district).map(&:name) if names.empty?

    names + Poi.transit_for(name, district).map(&:name)
  end

  def near_names(name, district)
    Street.near_for(name, district).map(&:name).presence || Poi.near_for(name, district).map(&:name)
  end
end
