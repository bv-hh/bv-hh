# frozen_string_literal: true

class AddAllrisTypeToCommittees < ActiveRecord::Migration[8.0]
  def change
    add_column :committees, :allris_type, :string, default: 'au'
  end
end
