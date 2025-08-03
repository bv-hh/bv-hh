class RemoveEmbeddingsCreatedFromDocuments < ActiveRecord::Migration[8.0]
  def change
    remove_column :documents, :embeddings_created, :boolean
  end
end
