class AddMinutesToAgendaItem < ActiveRecord::Migration[6.1]
  def change
    add_column :agenda_items, :minutes, :text
  end
end
