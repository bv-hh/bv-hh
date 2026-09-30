# frozen_string_literal: true

class CreateTopicModels < ActiveRecord::Migration[8.1]
  def change
    create_table :topic_models do |t|
      t.string :topic, null: false, index: { unique: true }
      t.string :model, null: false
      t.vector :weights, limit: 768, null: false
      t.float :bias, null: false
      t.float :threshold, null: false
      t.jsonb :metrics, null: false, default: {}
      t.timestamps
    end
  end
end
