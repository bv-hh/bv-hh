# frozen_string_literal: true

class UpdateGroupJob < ApplicationJob
  queue_as :groups

  def perform(group)
    group.retrieve_from_allris!
  end
end
