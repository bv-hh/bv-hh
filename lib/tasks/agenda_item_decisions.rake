# frozen_string_literal: true

namespace :agenda_items do
  # Fills agenda_items.minutes_decision from the stored result and minutes, as
  # AgendaItem#read_minutes_decision does on save, after a change to
  # MinutesDecision too. Asks ALLRIS nothing and can run again: it writes only
  # the items whose decision from the text differs.
  desc 'Read the decision from the result and minutes of agenda items ALLRIS leaves open'
  task decisions: :environment do
    changed = 0
    items = AgendaItem.where.not(document_id: nil).where.not(decision: AgendaItem::OUTCOMES.keys).or(
      AgendaItem.where.not(document_id: nil).where(decision: nil)
    ).or(AgendaItem.where.not(minutes_decision: nil))
    items.includes(:document).find_each.with_index(1) do |item, index|
      before = item.minutes_decision
      item.read_minutes_decision
      if item.minutes_decision != before
        item.update_column(:minutes_decision, item.minutes_decision) # rubocop:disable Rails/SkipsModelValidations
        changed += 1
      end
      puts "#{index} checked, #{changed} changed" if (index % 10_000).zero?
    end
    puts "#{changed} agenda items changed."
  end
end
