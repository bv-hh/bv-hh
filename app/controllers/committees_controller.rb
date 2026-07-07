# frozen_string_literal: true

class CommitteesController < ApplicationController
  def index
    @committees = @district.committees.open.order(:inactive, :order)
    @title = "Gremien und Ausschüsse der Bezirksversammlung #{@district.name}"
  end

  def show
    @committee = @district.committees.find(params[:id])
    @timeline_series = committee_timeline_series(@committee)
    @recent_averages = @committee.recent_averages
    @meetings = @committee.meetings.with_agenda.latest_first.to_a
    @meeting_stats = meeting_stats(@meetings)
    @memberships = ordered_memberships(@committee)
    @title = "#{@committee.name} - #{@committee.district.name}"
  end

  private

  # Per-meeting figures for the meetings table, aggregated in a few grouped
  # queries keyed by meeting id, so the view never touches the (heavy) agenda
  # item text or fires a query per row.
  def meeting_stats(meetings)
    ids = meetings.map(&:id)
    items = AgendaItem.where(meeting_id: ids)

    {
      agenda_item_counts: items.group(:meeting_id).count,
      word_counts: items.group(:meeting_id).sum(:word_count),
      logged_meeting_ids: items.logged.distinct.pluck(:meeting_id).to_set,
    }
  end

  # Two aligned monthly series for the combined committee chart: number of
  # documents and total minutes word count, both over the last 12 months. The
  # word-count series is bound to a secondary y-axis (see the view) because its
  # scale (thousands) dwarfs the document counts (tens).
  def committee_timeline_series(committee)
    documents = @district.documents.committee(committee).in_last_months(12)
                         .group_by_month('meetings.date').count
                         .transform_keys(&:to_date)
    words = committee.meetings.with_minutes.where(date: 12.months.ago..Time.zone.today)
                     .joins(:agenda_items)
                     .group_by_month('meetings.date').sum('agenda_items.word_count')
                     .transform_keys(&:to_date)

    [
      { name: 'Anzahl Drucksachen', data: documents },
      { name: 'Umfang der Niederschriften (Wörter)', data: words, dataset: { yAxisID: 'words' } },
    ]
  end

  # Group members by party, ordering parties by their overall size (number of
  # regular members in the district), largest first; members without a party
  # last. Within a party, order by name.
  def ordered_memberships(committee)
    party_sizes = @district.members.active.regular.group(:party_id).count

    committee.memberships.active.joins(:member).merge(Member.active).includes(member: :party).sort_by do |membership|
      party_id = membership.member.party_id
      [party_id ? 0 : 1, party_id ? -party_sizes[party_id].to_i : 0, membership.member.party&.name.to_s, membership.member.name.to_s]
    end
  end
end
