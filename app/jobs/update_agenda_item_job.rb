# frozen_string_literal: true

class UpdateAgendaItemJob < ApplicationJob
  queue_as :meetings

  def perform(agenda_item)
    agenda_item.retrieve_from_allris!
  end
end
