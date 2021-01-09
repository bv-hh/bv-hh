# frozen_string_literal: true

class StatisticsController < ApplicationController
  PARTIES = {
    'CDU' => '#222',
    'SPD' => '#dc3545',
    'Grüne' => '#28a745',
    'FDP' => '#ffc107',
    'Linke' => '#c535dc',
    'AfD' => '#17a2b8',
  }.freeze

  def show
    set_charts

    @total_documents = @district.documents.since_number(@district.first_legislation_number).count
    @documents_timeline = @district.documents.since_number(@district.first_legislation_number).joins(:meetings).group_by_month('meetings.date').count
    @proposals_timeline = @district.documents.since_number(@district.first_legislation_number).joins(:meetings).proposals.group_by_month('meetings.date').count
  end

  def make_chart_data(caption)
    PARTIES.map do |party, color|
      {
        name: party,
        color: color,
        data: {
          caption => yield(party),
        },
      }
    end
  end

  def set_charts
    @proposals = make_chart_data('Anträge') do |party|
      @district.documents.since_number(@district.first_legislation_number).proposals_by(party).count
    end

    @small_inquiries = make_chart_data('Anfragen') do |party|
      @district.documents.since_number(@district.first_legislation_number).small_inquiries(party).count
    end

    @large_inquiries = make_chart_data('Anfragen') do |party|
      @district.documents.since_number(@district.first_legislation_number).large_inquiries(party).count
    end
  end
end
