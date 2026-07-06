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
#  stadtteil       :string
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

  def self.normalize(name)
    name&.downcase&.gsub(/[^[:alnum:]]+/, ' ')&.strip
  end

  private

  def normalize_name
    self.normalized_name = self.class.normalize(name)
  end
end
