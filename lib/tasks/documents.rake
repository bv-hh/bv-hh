# frozen_string_literal: true

namespace :documents do
  # After a bump of Parsing::VERSION: brings every document whose page is stored
  # up to date at once, without a request to ALLRIS. RefetchDocumentsJob would
  # get there too, but only within its nightly window. Documents without a
  # stored page are left to that job.
  desc 'Parse stored ALLRIS pages again for documents parsed by an older parser'
  task reparse: :environment do
    documents = Document.parsed_before(Parsing::VERSION).where.associated(:allris_page)
    total = documents.count
    failed = 0

    documents.find_each.with_index(1) do |document, index|
      document.reparse!
    rescue StandardError => e
      failed += 1
      warn "#{document.id} (#{document.number}): #{e.class}: #{e.message}"
    ensure
      puts "#{index}/#{total}" if (index % 500).zero?
    end

    puts "Reparsed #{total - failed} of #{total} documents, #{failed} failed."
  end

  # Fills Document#referenced_numbers from the stored text, after the column was
  # added or REFERENCE changed. Needs no request to ALLRIS; writes only the rows
  # whose references differ.
  desc 'Extract the Drucksache numbers each document names from its stored text'
  task references: :environment do
    changed = 0
    Document.unscoped.where.not(full_text: nil).select(:id, :number, :full_text, :referenced_numbers)
            .find_each.with_index(1) do |document, index|
      numbers = Document.references_in(document.full_text, document.number)
      if numbers != document.referenced_numbers
        document.update_column(:referenced_numbers, numbers) # rubocop:disable Rails/SkipsModelValidations
        changed += 1
      end
      puts "#{index} checked, #{changed} changed" if (index % 10_000).zero?
    end
    puts "#{changed} documents changed."
  end
end
