# frozen_string_literal: true

class Member < ApplicationRecord

  CHAIR_KINDS = ['Fraktionsvorsitz', 'Fraktionsvorsitzende/r']
  DEPUTY_CHAIR_KINDS = ['Stellv. Fraktionsvorsitz', 'Stellvertr. Fraktionsvorsitz']
  ELECTED_KINDS = CHAIR_KINDS + DEPUTY_CHAIR_KINDS + ['Fraktionsmitglied']

  belongs_to :group

  has_many :committee_members, dependent: :destroy
  has_many :committees, through: :committee_members

  scope :lead, -> { where(kind: CHAIR_KINDS + DEPUTY_CHAIR_KINDS) }
  scope :elected, -> { where(kind: ELECTED_KINDS) }
end
