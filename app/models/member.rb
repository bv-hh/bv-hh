# frozen_string_literal: true

# == Schema Information
#
# Table name: members
#
#  id         :bigint           not null, primary key
#  kind       :string
#  kind_order :integer          default(0)
#  last_name  :string
#  name       :string
#  short_name :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  allris_id  :integer
#  group_id   :bigint
#
# Indexes
#
#  index_members_on_group_id                  (group_id)
#  index_members_on_kind_order_and_last_name  (kind_order DESC,last_name)
#  index_members_on_short_name                (short_name)
#
class Member < ApplicationRecord
  CHAIR_KINDS = ['Fraktionsvorsitz', 'Fraktionsvorsitzende/r']
  DEPUTY_CHAIR_KINDS = ['Stellv. Fraktionsvorsitz', 'Stellvertr. Fraktionsvorsitz',
                        '1. stellvertr. Fraktionsvorsitz', '2. stellvertr. Fraktionsvorsitz',
                        '1. stv. Fraktionsvorsitzende/r', '2. stv. Fraktionsvorsitzende/r']
  MEMBER_KINDS = ['Fraktionsmitglied']
  ELECTED_KINDS = CHAIR_KINDS + DEPUTY_CHAIR_KINDS + MEMBER_KINDS

  belongs_to :group

  has_many :committee_members, dependent: :destroy
  has_many :committees, through: :committee_members

  scope :chair, -> { where(kind: CHAIR_KINDS) }
  scope :deputy_chair, -> { where(kind: DEPUTY_CHAIR_KINDS) }
  scope :lead, -> { where(kind: CHAIR_KINDS + DEPUTY_CHAIR_KINDS) }
  scope :elected, -> { where(kind: ELECTED_KINDS) }

  scope :ordered_by_kind_and_name, -> { order(kind_order: :desc, last_name: :asc) }

  before_save :set_kind_order
  before_save :set_last_name

  def to_param
    "#{name.parameterize}-#{id}"
  end

  def kind_order_from_kind
    if CHAIR_KINDS.include?(kind)
      50
    elsif DEPUTY_CHAIR_KINDS.include?(kind)
      40
    elsif MEMBER_KINDS.include?(kind)
      30
    else
      10
    end
  end

  private

  def set_kind_order
    self.kind_order = kind_order_from_kind
  end

  def set_last_name
    self.last_name = name&.split&.last
  end
end
