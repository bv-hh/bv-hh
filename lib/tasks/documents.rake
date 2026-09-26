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
end
