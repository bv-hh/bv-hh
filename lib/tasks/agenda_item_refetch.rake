# frozen_string_literal: true

namespace :agenda_items do
  # Fetches once more the agenda items of a Drucksache that have neither a
  # decision nor any text, from meetings older than a month; the minutes of
  # younger ones are often not out yet. UpdateSlowlyChangingContentJob retries
  # such items only up to 270 days. Most are Wandsbek items whose page ALLRIS
  # sent to noauth.asp before AgendaItem#source_from asked again with a
  # session. One request at a time, PAUSE seconds apart (default 3), for
  # meetings since SINCE (default three years ago). Can run again.
  desc 'Fetch again the agenda items of a Drucksache left without decision and text'
  task refetch_empty: :environment do
    since = ENV.fetch('SINCE') { 3.years.ago.to_date.to_s }.to_date
    pause = ENV.fetch('PAUSE', '3').to_f
    items = AgendaItem.joins(:meeting).includes(meeting: :district)
                      .where.not(allris_id: nil).where.not(document_id: nil)
                      .where(decision: [nil, ''], minutes: nil, result: nil)
                      .where(meetings: { date: since..1.month.ago.to_date })
    total = items.count
    filled = 0
    failed = 0

    items.find_each.with_index(1) do |item, index|
      item.retrieve_from_allris!
      filled += 1 if item.reload.decision.present? || item.minutes || item.result
    rescue StandardError => e
      failed += 1
      warn "#{item.id}: #{e.class}: #{e.message}"
    ensure
      puts "#{index}/#{total}, #{filled} filled" if (index % 25).zero?
      sleep pause
    end
    puts "#{total} fetched, #{filled} now have a decision or text, #{failed} failed."
  end
end
