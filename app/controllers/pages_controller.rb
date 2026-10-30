# frozen_string_literal: true

class PagesController < ApplicationController
  # Topics shown as bars on the home page; the rest follow as plain links.
  TOP_TOPICS = 8

  before_action :without_district

  def home
    @hero_search = true
    @districts = District.by_order.to_a
    @document_counts = Document.complete.group(:district_id).count
    @meeting_count = Meeting.complete.count
    @quarter_names = Quarter.by_name.pluck(:district_number, :name)
                            .group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
    @next_assemblies = next_assemblies
    @topic_counts = cached_topic_counts(:district, nil) { Document.complete }
  end

  def imprint; end

  def privacy; end

  def about; end

  def transparency; end

  def mcp; end

  def district_politics; end

  def participation; end

  private

  # The next plenary session of each district, soonest first.
  def next_assemblies
    Meeting.complete.of_assembly.in_future.includes(:district)
           .select('DISTINCT ON (meetings.district_id) meetings.*')
           .order('meetings.district_id, meetings.date, meetings.start_time')
           .sort_by { |meeting| [meeting.date, meeting.district.order] }
  end
end
