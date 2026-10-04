# frozen_string_literal: true

# Turns documents into DocumentEmbeddings with multilingual-e5-base, run
# locally through ONNX (the informers gem). The model takes ~0.8 GB once
# loaded, more than a web or worker process can spare for good, so it runs in
# a process of its own: `rake embeddings:update`, started nightly by
# EmbedDocumentsJob, which exits and gives the memory back.
class DocumentEmbedder
  MODEL = 'Xenova/multilingual-e5-base'
  DTYPE = 'q8'
  # Stored with every embedding. Vectors of different models don't compare, so
  # a backfill made elsewhere is only imported if this matches.
  NAME = "#{MODEL}:#{DTYPE}".freeze
  # e5 reads 512 tokens, about 2000 characters of German. Longer input is cut
  # off by the tokenizer anyway, it would only take longer to get there.
  TEXT_LIMIT = 2000
  # e5 was trained with this prefix on the texts to be found ("query: " on
  # what is searched for).
  PREFIX = 'passage: '

  # The documents without an embedding of the current model and text.
  def self.outdated
    Document.complete.left_joins(:embedding)
            .where('document_embeddings.id IS NULL OR document_embeddings.model <> :name ' \
                   "OR document_embeddings.digest <> #{digest_sql}", name: NAME)
  end

  # The text as Postgres builds it for the digest, character for character
  # what text(document) builds in Ruby.
  def self.digest_sql
    "md5(COALESCE(documents.title, '') || E'\\n' || LEFT(COALESCE(documents.full_text, ''), #{TEXT_LIMIT}))"
  end

  def self.text(document)
    "#{document.title}\n#{document.full_text.to_s[0, TEXT_LIMIT]}"
  end

  def self.digest(document)
    Digest::MD5.hexdigest(text(document))
  end

  # The pipeline can be passed in, so tests don't load the model.
  def initialize(pipeline = nil)
    @pipeline = pipeline
  end

  # One document at a time: e5 on a batch pads every text to the longest one,
  # which is slower per document and takes several times the memory.
  def embed(document)
    pipeline.call([PREFIX + self.class.text(document)]).first
  end

  # Embeds and stores one document, replacing an embedding it had.
  def update(document)
    DocumentEmbedding.upsert( # rubocop:disable Rails/SkipsModelValidations
      { document_id: document.id, model: NAME, digest: self.class.digest(document), embedding: embed(document) },
      unique_by: :document_id
    )
  end

  private

  def pipeline
    @pipeline ||= begin
      require 'informers'
      Informers.pipeline('embedding', MODEL, dtype: DTYPE)
    end
  end
end
