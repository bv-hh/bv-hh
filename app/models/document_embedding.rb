# == Schema Information
#
# Table name: document_embeddings
#
#  id          :integer          not null, primary key
#  document_id :integer          not null
#  model       :string           not null
#  digest      :string           not null
#  embedding   :vector(768)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_document_embeddings_on_document_id  (document_id) UNIQUE
#  index_document_embeddings_on_embedding    (embedding)
#

# frozen_string_literal: true

# The meaning of a document as a vector, computed by DocumentEmbedder from its
# title and the start of its full text. One per document; digest is the MD5 of
# that text, so a document whose text changed is embedded again.
class DocumentEmbedding < ApplicationRecord
  belongs_to :document

  has_neighbors :embedding
end
