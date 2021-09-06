class AddAllrisIdToAgendaItem < ActiveRecord::Migration[6.1]
  def change
    add_column :agenda_items, :allris_id, :integer, index: true
  end
end
