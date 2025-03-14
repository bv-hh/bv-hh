# frozen_string_literal: true

# == Schema Information
#
# Table name: committee_members
#
#  id           :bigint           not null, primary key
#  kind         :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  committee_id :bigint
#  member_id    :bigint
#
# Indexes
#
#  index_committee_members_on_committee_id  (committee_id)
#  index_committee_members_on_member_id     (member_id)
#
class CommitteeMember < ApplicationRecord

  belongs_to :committee
  belongs_to :member
end
