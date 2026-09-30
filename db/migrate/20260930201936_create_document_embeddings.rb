# frozen_string_literal: true

class CreateDocumentEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :document_embeddings do |t|
      t.references :document, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.string :model, null: false
      t.string :digest, null: false
      t.vector :embedding, limit: 768, null: false
      t.timestamps
    end

    add_index :document_embeddings, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
