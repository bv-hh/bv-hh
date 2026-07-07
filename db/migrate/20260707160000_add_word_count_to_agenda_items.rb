# frozen_string_literal: true

# Cache the HTML-stripped word count of each agenda item's minutes/result so the
# committee page can aggregate "discussion volume" in SQL instead of running
# Nokogiri strip_tags over every item on every request.
class AddWordCountToAgendaItems < ActiveRecord::Migration[8.1]
  def up
    add_column :agenda_items, :word_count, :integer, default: 0, null: false

    # Backfill existing rows with the same Ruby computation used on save, so the
    # cached values match what the app has always displayed.
    say_with_time 'Backfilling agenda_items.word_count' do
      count = 0
      AgendaItem.where.not(minutes: nil).or(AgendaItem.where.not(result: nil)).find_each do |item|
        item.update_column(:word_count, item.send(:computed_word_count)) # rubocop:disable Rails/SkipsModelValidations
        count += 1
      end
      count
    end
  end

  def down
    remove_column :agenda_items, :word_count
  end
end
