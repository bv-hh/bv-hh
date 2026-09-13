# frozen_string_literal: true

# The one query behind both the RSS feed and the Quarter pages: Drucksachen
# that mention a location in any of the selected Quarters, or that mention any
# of the selected streets by name.
#
# Nothing here is persisted. A subscription is just a URL, which is what keeps
# the feature free of personal data.
#
# The two selection kinds are OR'd, with the semantics the feature was specified
# with:
#
#   street    — "whenever this street is mentioned, whatever the actual street
#               boundaries are": a pure name match, ignoring geometry and
#               district, so a name occurring in two districts matches both.
#   Quarter — "everything mentioning a location within this Quarter,
#               including partial streets": a street crossing three Quarters
#               matches all three, which is what locations.quarters stores.
class FeedQuery
  MAX_ITEMS = 50
  # Per selection kind. Past this the extra terms are dropped rather than
  # rejected: a feed reader cannot act on a 4xx, and many cache it hard enough
  # never to poll again.
  MAX_TERMS = 25

  # An EXISTS semi-join rather than a join with DISTINCT. DISTINCT would be
  # correct (documents.id is in the select list, so the dedup is exact) but it
  # forces Postgres to materialise every matching document before LIMIT applies.
  # EXISTS lets the planner walk documents backwards along
  # index_documents_on_created_at_public_complete and stop once it has enough.
  MATCH = <<~SQL.squish
    EXISTS (
      SELECT 1 FROM document_locations dl
      JOIN locations l ON l.id = dl.location_id
      WHERE dl.document_id = documents.id AND (%<conditions>s)
    )
  SQL

  attr_reader :district, :quarters, :street_names

  # Every value is canonicalised and validated against the database here, so the
  # relation can never see one that is not already in it.
  def self.from_params(params)
    new(district: District.lookup(params[:district].to_s),
        quarters: list_param(params[:quarters]),
        streets: list_param(params[:streets]))
  end

  # Rack is happy to parse ?quarters[a]=x into a Hash and ?quarters=x into a
  # String, so Array() is not enough — it would turn a Hash into pairs. Nested
  # values are dropped outright: an Array reaching ARRAY[?]::varchar[] builds a
  # malformed literal.
  def self.list_param(raw)
    values = case raw
    when String then [raw]
    when Array then raw
    when Hash, ActionController::Parameters then raw.values
    else []
    end

    values.select { |value| value.is_a?(String) }.filter_map { |value| value.strip.presence }.uniq.first(MAX_TERMS)
  end

  # district narrows; quarters and streets widen. "Hamburg-Nord plus Eppendorf"
  # means Eppendorf's documents that belong to Hamburg-Nord, not both sets — the
  # other reading would make the Stadtteil selection meaningless, since the
  # district already contains it.
  def initialize(district: nil, quarters: [], streets: [])
    @district = district
    # locations.quarters holds the register's own casing and PG's && is exact,
    # so a lowercase query param has to be mapped back before it reaches SQL.
    @quarters = Quarter.canonical_names(quarters)
    @street_names = canonical_street_names(streets)
  end

  def empty?
    district.blank? && !places?
  end

  # Whether a place filter was given at all. A district on its own needs no
  # locations: it is simply every Drucksache of that district.
  def places?
    quarters.any? || street_names.any?
  end

  def relation(limit: MAX_ITEMS, order: :created_at)
    return Document.none if empty?

    scope = documents
    scope = scope.where(district: district) if district.present?
    scope = scope.where(*match_condition) if places?
    scope = order == :created_at ? scope.order(created_at: :desc) : scope.latest_first
    limit ? scope.limit(limit) : scope
  end

  # Order-independent, and built from the sanitised terms rather than the raw
  # ones, so ?a=1&b=2 and ?b=2&a=1 share an ETag.
  def cache_key
    Digest::SHA256.hexdigest([district&.id, quarters.sort, street_names.sort].to_json)
  end

  def description
    parts = []
    parts << "Bezirk: #{district.name}" if district.present?
    parts << "Stadtteile: #{quarters.to_sentence}" if quarters.any?
    parts << "Straßen: #{street_display_names.to_sentence}" if street_names.any?
    parts.join(' · ')
  end

  def street_display_names
    @street_display_names ||= Street.where(normalized_name: street_names).distinct.order(:name).pluck(:name)
  end

  private

  # noindex is the mechanism behind the takedown requests documented on
  # /transparency. It is not in Document's default_scope, so both syndication
  # surfaces have to exclude it explicitly.
  def documents
    Document.complete.where(noindex: false)
  end

  def canonical_street_names(streets)
    keys = Array(streets).filter_map { |street| Street.normalize(street).presence }.uniq

    return [] if keys.empty?

    Street.where(normalized_name: keys).distinct.pluck(:normalized_name)
  end

  def match_condition
    conditions = []
    binds = {}

    if street_names.any?
      conditions << 'l.street_name IN (:street_names)'
      binds[:street_names] = street_names
    end

    if quarters.any?
      conditions << 'l.quarters && ARRAY[:quarters]::varchar[]'
      binds[:quarters] = quarters
    end

    [format(MATCH, conditions: conditions.join(' OR ')), binds]
  end
end
