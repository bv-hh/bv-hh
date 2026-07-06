# frozen_string_literal: true

class UpdateCommitteeMembersJob < ApplicationJob
  queue_as :committees

  def perform(committee)
    committee.retrieve_members_from_allris!
  end
end
