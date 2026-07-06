# frozen_string_literal: true

# == Schema Information
#
# Table name: memberships
#
#  id           :integer          not null, primary key
#  committee_id :integer
#  member_id    :integer
#  role         :string
#  inactive     :boolean          default(FALSE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_memberships_on_committee_id                (committee_id)
#  index_memberships_on_committee_id_and_member_id  (committee_id,member_id) UNIQUE
#  index_memberships_on_member_id                   (member_id)
#

class Membership < ApplicationRecord
  belongs_to :committee
  belongs_to :member

  scope :active, -> { where(inactive: false) }
end
