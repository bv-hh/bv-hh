# frozen_string_literal: true

class EnableVector < ActiveRecord::Migration[8.1]
  def change
    enable_extension 'vector'
  end
end
