# frozen_string_literal: true

namespace :embeddings do
  # Embeds every document without a current embedding: the nightly run
  # (EmbedDocumentsJob starts it), and the initial backfill, which takes hours
  # and can be interrupted and started again. Newest documents first.
  desc 'Embed documents that have no embedding of the current model and text'
  task update: :environment do
    documents = DocumentEmbedder.outdated
    total = documents.count
    embedder = DocumentEmbedder.new
    failed = 0

    documents.reorder(id: :desc).find_each(order: :desc).with_index(1) do |document, index|
      embedder.update(document)
    rescue StandardError => e
      failed += 1
      warn "#{document.id} (#{document.number}): #{e.class}: #{e.message}"
    ensure
      puts "#{index}/#{total}" if (index % 500).zero?
    end

    puts "Embedded #{total - failed} of #{total} documents, #{failed} failed."
  end

  # Documents are identified by district and ALLRIS id, which are the same in
  # every environment; ids are not.
  desc 'Write all embeddings to a gzipped file for embeddings:import elsewhere'
  task :export, [:file] => :environment do |_task, args|
    file = args[:file] || 'embeddings.tsv.gz'
    sql = <<~SQL.squish
      COPY (
        SELECT districts.name, documents.allris_id, document_embeddings.model, document_embeddings.digest,
               document_embeddings.embedding
        FROM document_embeddings
        JOIN documents ON documents.id = document_embeddings.document_id
        JOIN districts ON districts.id = documents.district_id
      ) TO STDOUT
    SQL

    count = 0
    Zlib::GzipWriter.open(file) do |gz|
      ActiveRecord::Base.connection.raw_connection.copy_data(sql) do
        while (row = ActiveRecord::Base.connection.raw_connection.get_copy_data)
          gz.write(row)
          count += 1
        end
      end
    end
    puts "Wrote #{count} embeddings to #{file}."
  end

  # Imports what embeddings:export wrote. A row is taken only if its model is
  # DocumentEmbedder::NAME and its digest matches the document's text here, so
  # a document that changed since is left to the next embeddings:update.
  desc 'Read embeddings written by embeddings:export'
  task :import, [:file] => :environment do |_task, args|
    file = args[:file] || 'embeddings.tsv.gz'
    connection = ActiveRecord::Base.connection

    connection.transaction do
      connection.execute(<<~SQL.squish)
        CREATE TEMPORARY TABLE imported_embeddings (
          district text, allris_id integer, model text, digest text, embedding vector(768)
        ) ON COMMIT DROP
      SQL

      raw = connection.raw_connection
      raw.copy_data('COPY imported_embeddings FROM STDIN') do
        Zlib::GzipReader.open(file) { |gz| gz.each_line { |line| raw.put_copy_data(line) } }
      end

      imported = connection.exec_update(<<~SQL.squish)
        INSERT INTO document_embeddings (document_id, model, digest, embedding, created_at, updated_at)
        SELECT documents.id, imported.model, imported.digest, imported.embedding, now(), now()
        FROM imported_embeddings imported
        JOIN districts ON districts.name = imported.district
        JOIN documents ON documents.district_id = districts.id AND documents.allris_id = imported.allris_id
        WHERE imported.model = #{connection.quote(DocumentEmbedder::NAME)}
          AND imported.digest = #{DocumentEmbedder.digest_sql}
        ON CONFLICT (document_id) DO UPDATE
          SET model = EXCLUDED.model, digest = EXCLUDED.digest, embedding = EXCLUDED.embedding,
              updated_at = EXCLUDED.updated_at
      SQL
      read = connection.select_value('SELECT count(*) FROM imported_embeddings')

      puts "Imported #{imported} of #{read} embeddings; the rest are for another model or a changed text."
    end
  end
end
