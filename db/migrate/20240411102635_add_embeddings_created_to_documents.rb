class AddEmbeddingsCreatedToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :embeddings_created, :boolean, default: false
  end
end
