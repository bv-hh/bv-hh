# frozen_string_literal: true

class AddAverageWordCountToCommittees < ActiveRecord::Migration[8.1]
  def change
    add_column :committees, :average_word_count, :integer
  end
end
