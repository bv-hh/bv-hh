# frozen_string_literal: true

# The decision MinutesDecision reads from an agenda item's text where ALLRIS
# leaves it "(offen)", kept apart from agenda_items.decision so the two
# sources stay distinguishable. A nullable column without a default rewrites
# no rows; the short lock_timeout keeps it from queueing writes behind a long
# transaction. rake agenda_items:decisions fills it.
class AddMinutesDecisionToAgendaItems < ActiveRecord::Migration[8.1]
  def up
    execute "SET LOCAL lock_timeout = '5s'"
    add_column :agenda_items, :minutes_decision, :string, if_not_exists: true
  end

  def down
    remove_column :agenda_items, :minutes_decision
  end
end
