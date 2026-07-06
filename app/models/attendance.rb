# frozen_string_literal: true

# == Schema Information
#
# Table name: attendances
#
#  id         :bigint           not null, primary key
#  name       :string
#  party_hint :string
#  present    :boolean          default(TRUE), not null
#  role       :string
#  substitute :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  meeting_id :bigint
#  member_id  :bigint
#
# Indexes
#
#  index_attendances_on_meeting_id                (meeting_id)
#  index_attendances_on_meeting_id_and_member_id  (meeting_id,member_id) UNIQUE
#  index_attendances_on_member_id                 (member_id)
#
class Attendance < ApplicationRecord
  belongs_to :meeting
  belongs_to :member, optional: true

  scope :present, -> { where(present: true) }
  scope :matched, -> { where.not(member_id: nil) }
  scope :substitutes, -> { where(substitute: true) }
end
