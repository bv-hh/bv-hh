# frozen_string_literal: true

class StatisticsController < ApplicationController
  PARTIES = {
    'CDU' => '#222',
    'SPD' => '#dc3545',
    'Grüne' => '#28a745',
    'FDP' => '#ffc107',
    'Linke' => '#c535dc',
    'Volt' => '#502379',
    'AfD' => '#add8e6',
  }.freeze

  def show
    @title = "Statistiken zur Bezirkspolitik in #{@district.name}"

    set_charts

    @total_documents = Document.current_legislation(@district).count
    @documents_timeline = Document.current_legislation(@district).joins(:meetings).group_by_month('meetings.date').count
    @proposals_timeline = Document.current_legislation(@district).joins(:meetings).proposals.group_by_month('meetings.date').count
  end

  def make_chart_data(caption)
    PARTIES.map do |party, color|
      {
        name: party,
        color:,
        data: {
          caption => yield(party),
        },
      }
    end
  end

  def set_charts
    @proposals = make_chart_data('Anträge') do |party|
      Document.current_legislation(@district).proposals_by(party).count
    end

    @small_inquiries = make_chart_data('Anfragen') do |party|
      Document.current_legislation(@district).small_inquiries(party).count
    end

    @large_inquiries = make_chart_data('Anfragen') do |party|
      Document.current_legislation(@district).large_inquiries(party).count
    end
  end
end
