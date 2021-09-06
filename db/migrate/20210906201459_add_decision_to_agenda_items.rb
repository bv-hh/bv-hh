class AddDecisionToAgendaItems < ActiveRecord::Migration[6.1]
  def change
    add_column :agenda_items, :decision, :string, index: true
  end
end
