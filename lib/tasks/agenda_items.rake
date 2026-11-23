# frozen_string_literal: true

namespace :agenda_items do
  # Fills agenda_items.referenced_numbers from the stored title, minutes and
  # result, as AgendaItem#extract_references does on save. Asks ALLRIS nothing
  # and can run again: it writes only the items whose references differ.
  desc 'Extract the Drucksache numbers each agenda item names from its stored title, minutes and result'
  task references: :environment do
    changed = 0
    AgendaItem.select(:id, :title, :minutes, :result, :referenced_numbers).find_each.with_index(1) do |item, index|
      numbers = Document.references_in(item.reference_text, nil)
      if numbers != item.referenced_numbers
        item.update_column(:referenced_numbers, numbers) # rubocop:disable Rails/SkipsModelValidations
        changed += 1
      end
      puts "#{index} checked, #{changed} changed" if (index % 10_000).zero?
    end
    puts "#{changed} agenda items changed."
  end
end
