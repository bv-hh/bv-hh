# frozen_string_literal: true

# == Schema Information
#
# Table name: members
#
#  id          :integer          not null, primary key
#  allris_id   :integer
#  district_id :integer
#  party_id    :integer
#  name        :string
#  kind        :string
#  inactive    :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_members_on_district_id                (district_id)
#  index_members_on_district_id_and_allris_id  (district_id,allris_id) UNIQUE
#  index_members_on_party_id                   (party_id)
#

class Member < ApplicationRecord
  # "Co-opted citizens" (zugewählte Bürger) are appointed experts, not elected
  # fraction members. The exact wording is stable across all seven Hamburg
  # districts' ALLRIS instances; only the capitalisation differs.
  CO_OPTED_KINDS = ['zubenannte/r Bürger/in', 'Zubenannte/r Bürger/in'].freeze

  belongs_to :district
  belongs_to :party, optional: true

  has_many :memberships, dependent: :destroy
  has_many :committees, through: :memberships

  scope :active, -> { where(inactive: false) }
  scope :co_opted, -> { where(kind: CO_OPTED_KINDS) }
  scope :regular, -> { where.not(kind: CO_OPTED_KINDS) }
  scope :by_name, -> { order(:name) }

  def co_opted?
    CO_OPTED_KINDS.include?(kind)
  end

  def allris_url
    raise 'Allris ID missing' if allris_id.blank?

    "#{district.allris_base_url}/bi/kp020.asp?KPLFDNR=#{allris_id}"
  end

  def to_param
    "#{name.parameterize}-#{id}"
  end
end
