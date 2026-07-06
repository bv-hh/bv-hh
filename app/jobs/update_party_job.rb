# frozen_string_literal: true

class UpdatePartyJob < ApplicationJob
  queue_as :committees

  def perform(party)
    party.retrieve_from_allris!
  end
end
