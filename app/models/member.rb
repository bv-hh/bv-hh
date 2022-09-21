# frozen_string_literal: true

class Member < ApplicationRecord

  belongs_to :group

  has_many :committee_members, dependent: :destroy
  has_many :committees, through: :committee_members
end
