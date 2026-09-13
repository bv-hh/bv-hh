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
#  bezirke         :integer          default([]), not null, is an Array
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_streets_on_bezirke          (bezirke) USING gin
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
  validates :name, presence: true
  validates :normalized_name, presence: true

  before_validation :normalize_name

  # Streets matching +name+ that belong to the district, per the register's own
  # Bezirk assignment (streets.bezirke). A street name can occur in several
  # districts, and long streets span multiple Bezirke, so this authoritative
  # membership check replaces any bounding-box heuristic. Returns [] for
  # districts without a known Bezirk number.
  def self.for(name, district)
    number = district.bezirk_number
    return none if number.blank?

    where(normalized_name: normalize(name)).where('bezirke @> ARRAY[?]::integer[]', number)
  end

  # Streets touching a given Quarter. A long street belongs to every
  # Quarter it crosses, not only the one holding its representative point,
  # so this queries the full quarters array rather than the singular column.
  scope :in_quarter, ->(name) { where('quarters @> ARRAY[?]::varchar[]', name.to_s) }

  # Streets touching a given official Ortsteil key from the register, e.g. "0405".
  scope :in_quarter_key, ->(key) { where('quarter_keys @> ARRAY[?]::varchar[]', key.to_s) }

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
