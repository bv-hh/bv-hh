# frozen_string_literal: true

class CommitteeMember < ApplicationRecord

  belongs_to :committee
  belongs_to :member
end
