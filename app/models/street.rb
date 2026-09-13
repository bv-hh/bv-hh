# frozen_string_literal: true

# == Schema Information
#
# Table name: streets
#
#  id              :integer          not null, primary key
#  name            :string           not null
#  normalized_name :string           not null
#  latitude        :float
#  longitude       :float
#  quarter       :string
#  quarters      :string           default([]), not null, is an Array
#  quarter_keys       :string           default([]), not null, is an Array
#  postal_code     :string
#  street_key      :string
#  district_numbers         :integer          default([]), not null, is an Array
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_streets_on_bezirke          (district_numbers) USING gin
#  index_streets_on_normalized_name  (normalized_name)
#  index_streets_on_ortsteile        (quarter_keys) USING gin
#  index_streets_on_quarters       (quarters) USING gin
#  index_streets_on_street_key       (street_key)
#

# Gazetteer of official Hamburg street names, imported from the "Zentraler
# AdressService" WFS (dog:Strassen). Used as the authoritative source for
# street/place extraction: names found in a document are looked up here and
# resolved to real coordinates without a Google Maps round-trip.
class Street < ApplicationRecord
  # Calibrated against the corpus: at 0.7 every correction in a sample of 171
  # was right ("Lehnhartzstraße" to "Lenhartzstraße", "Chrysander Straße" to
  # "Chrysanderstraße", "Stapel-felder Straße" to "Stapelfelder Straße").
  # Lowering it to 0.65 matches 238 instead of 171, at the cost of admitting
  # substitutions of a whole name component — "Julius-Strandes-Weg" becoming
  # "Justus-Strandes-Weg" — which is the kind of silent correction that made
  # Google untrustworthy. Pass `floor:` to measure another value.
  FUZZY_FLOOR = 0.7
  # How far the winner must be clear of the next different name.
  FUZZY_MARGIN = 0.05
  # Below this, near-identity is meaningless: "Elbweg" and "Erdweg" score high.
  FUZZY_MIN_LENGTH = 8
  FUZZY_CANDIDATES = 5

  validates :name, presence: true
  validates :normalized_name, presence: true

  before_validation :normalize_name

  # Streets matching +name+ that belong to the district, per the register's own
  # district assignment (streets.district_numbers). A street name can occur in several
  # districts, and long streets span multiple districts, so this authoritative
  # membership check replaces any bounding-box heuristic. Returns [] for
  # districts without a known number.
  def self.for(name, district)
    number = district.number
    return none if number.blank?

    where(normalized_name: canonical_name(name)).where('district_numbers @> ARRAY[?]::integer[]', number)
  end

  # The register's spelling of +name+: "krausestrasse" and "bramfelder str"
  # answer with "krausestraße" and "bramfelder straße". Falls back to the plain
  # normalization when no variant applies, so an unknown name is simply not
  # found rather than rewritten.
  def self.canonical_name(name)
    normalized = normalize(name)
    StreetGazetteer.canonical(normalized) || normalized
  end

  # Streets touching a given Quarter. A long street belongs to every
  # Quarter it crosses, not only the one holding its representative point,
  # so this queries the full quarters array rather than the singular column.
  scope :in_quarter, ->(name) { where('quarters @> ARRAY[?]::varchar[]', name.to_s) }

  # Streets touching a given official Ortsteil key from the register, e.g. "0405".
  scope :in_quarter_key, ->(key) { where('quarter_keys @> ARRAY[?]::varchar[]', key.to_s) }

  # Streets whose name is *nearly* +name+, for text the exact lookup misses.
  #
  # Documents are OCR'd PDFs: "Langenhomer Chaussee" (rn read as m),
  # "Hudtwalkerstraße", "Dorotheenstrasse". Google Places used to absorb these
  # silently, which is the only thing it did that the registers could not.
  #
  # Deliberately stricter than Google was. The search is confined to the
  # district, so it can never answer with a same-named street in Norderstedt.
  # It demands a high similarity, and it demands an unambiguous winner: where
  # two different street names score within MARGIN of each other, this returns
  # nothing rather than guess. Short names are refused outright — at four or
  # five characters everything is similar to everything.
  def self.fuzzy_for(name, district, floor: FUZZY_FLOOR)
    normalized = normalize(name)
    number = district.number
    return none if number.blank? || normalized.blank? || normalized.length < FUZZY_MIN_LENGTH

    best = unambiguous_match(normalized, number, floor)
    return none if best.blank?

    where(normalized_name: best).where('district_numbers @> ARRAY[?]::integer[]', number)
  end

  # The single best-scoring street name, or nil when the field is too close to
  # call. Compares against the runner-up with a *different* name: several rows
  # can carry one name, and those are the same answer, not a tie.
  def self.unambiguous_match(normalized, number, floor = FUZZY_FLOOR)
    scored = fuzzy_scores(normalized, number, floor)
    best = scored.first
    return nil if best.blank?

    runner_up = scored.find { |row| row.normalized_name != best.normalized_name }
    return nil if runner_up.present? && (best.score - runner_up.score) < FUZZY_MARGIN

    best.normalized_name
  end

  # The `%` operator is what uses the trigram index; the explicit similarity
  # floor is what makes the answer trustworthy. Both, because the operator's
  # own threshold is a session setting we do not control.
  def self.fuzzy_scores(normalized, number, floor = FUZZY_FLOOR)
    select(sanitize_sql_array(['streets.normalized_name, max(similarity(normalized_name, ?)) AS score', normalized]))
      .where('district_numbers @> ARRAY[?]::integer[]', number)
      .where(sanitize_sql_array(['normalized_name % ?', normalized]))
      .where(sanitize_sql_array(['similarity(normalized_name, ?) >= ?', normalized, floor]))
      .group(:normalized_name)
      .order(Arel.sql('score DESC'))
      .limit(FUZZY_CANDIDATES)
  end

  def self.normalize(name)
    name&.downcase&.gsub(/[^[:alnum:]]+/, ' ')&.strip
  end

  # True when the street crosses more than one Quarter.
  def crosses_quarters?
    quarters.size > 1
  end

  # Street-level address composed from the register's own fields, e.g.
  # "Bergedorfer Straße, 21029 Bergedorf". Uses the representative Quarter;
  # see +quarters+ for the full list. Used in place of a Google Maps
  # +formatted_address+ for gazetteer-resolved locations. Degrades gracefully
  # when postal_code or quarter are missing.
  def formatted_address
    locality = [postal_code, quarter].compact_blank.join(' ')
    [name, locality].compact_blank.join(', ')
  end

  private

  def normalize_name
    self.normalized_name = self.class.normalize(name)
  end
end
