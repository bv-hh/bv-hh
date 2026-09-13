# frozen_string_literal: true

# A name that must never become a Location. See LocationBlocklist for how the
# computed entries are derived; `manual` entries are added by hand and are never
# touched by the recompute.
#
# Keyed on Street.normalize, the more aggressive of the two normalisations in
# this codebase (it also collapses punctuation), so "Bezirk Hamburg-Nord" and
# "bezirk hamburg nord" are the same entry.
class BlockedLocationName < ApplicationRecord
  SOURCES = %w[computed manual].freeze

  validates :name, presence: true
  validates :normalized_name, presence: true, uniqueness: true
  validates :source, inclusion: { in: SOURCES }

  before_validation :normalize_name

  scope :computed, -> { where(source: 'computed') }
  scope :manual, -> { where(source: 'manual') }
  scope :by_name, -> { order(:name) }

  class << self
    def blocked?(name)
      key = key_for(name)
      return false if key.blank?

      keys.include?(key)
    end

    def key_for(name)
      Street.normalize(name)
    end

    # Drops the memoized set; call after changing the table.
    def reset!
      @keys = nil
    end

    private

    def keys
      @keys ||= Set.new(pluck(:normalized_name))
    end
  end

  private

  def normalize_name
    self.normalized_name = self.class.key_for(name)
  end
end
