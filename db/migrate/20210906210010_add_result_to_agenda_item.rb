class AddResultToAgendaItem < ActiveRecord::Migration[6.1]
  def change
    add_column :agenda_items, :result, :text
  end
end
