# frozen_string_literal: true

# The meetings of the next two weeks that concern a selection: those with an
# agenda item whose Drucksache matches the FeedQuery, and every meeting of the
# area committees of its Stadtteile (AreaCommittee), whose whole agenda is about
# the area. This is when people can still take part, unlike the feed, which
# looks back.
#
# Agendas appear about a week before a meeting. An area committee's meeting
# shows before that too, without items, so its date is known; a meeting of any
# other committee only once an item on it matches.
#
# Agenda items of future meetings are deleted and created again whenever
# the meeting is refreshed (Meeting#retrieve_agenda_items), so nothing here
# keeps their ids.
class UpcomingQuery
  HORIZON = 14.days

  # items: the matching agenda items, in agenda order. area: whether the
  # meeting is one of an area committee of the selection. question_time: the
  # public question time item, if the agenda has one.
  Entry = Struct.new(:meeting, :items, :area, :question_time, keyword_init: true) do
    def agenda?
      meeting.agenda_items.any?
    end
  end

  def initialize(query, today: Time.zone.today)
    @query = query
    @dates = today..(today + HORIZON)
  end

  def entries
    @entries ||= begin
      items = matching_items.group_by(&:meeting_id)
      area_ids = area_meetings.pluck(:id).to_set

      meetings.where(id: items.keys + area_ids.to_a).map do |meeting|
        # Items are stored in the order of the agenda, and numbers like "Ö 10"
        # don't sort.
        Entry.new(meeting:, items: items.fetch(meeting.id, []).sort_by(&:id), area: area_ids.include?(meeting.id),
                  question_time: meeting.agenda_items.sort_by(&:id).find(&:question_time?))
      end
    end
  end

  delegate :empty?, :any?, :size, :each, to: :entries

  private

  def meetings
    Meeting.complete.where(date: @dates).includes(:district, :committee, :agenda_items).order(:date, :start_time)
  end

  def matching_items
    return AgendaItem.none if @query.empty?

    AgendaItem.joins(:meeting).merge(Meeting.complete.where(date: @dates))
              .where(document_id: @query.matching.select(:id)).includes(:document)
  end

  # A topic narrows the selection to that topic, so it also leaves out the
  # area committees' meetings that have nothing about it.
  def area_meetings
    return Meeting.none if @query.quarters.empty? || @query.topics.any?

    Meeting.complete.where(date: @dates, committee: AreaCommittee.committees_for(@query.quarters))
  end
end
