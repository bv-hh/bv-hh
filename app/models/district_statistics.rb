# frozen_string_literal: true

# The figures behind the statistics page, all for a district's current
# legislation: which topics it deals with, what came of its Anträge, which
# Stadtteile its Drucksachen name, how busy it has been, and how many Anträge
# and Anfragen each Fraktion put forward.
#
# Everything is computed on first use, so the page can cache what it renders
# and skip the queries.
class DistrictStatistics
  # Topics followed over time. More lines than this stop being readable.
  TIMELINE_TOPICS = 5
  # Topics broken down by outcome, and how many Anträge one needs for its
  # shares to mean something.
  OUTCOME_TOPICS = 8
  MIN_PROPOSALS_PER_TOPIC = 10

  # What came of an Antrag, in the order the page stacks them.
  OUTCOMES = {
    adopted: 'Beschlossen',
    rejected: 'Abgelehnt',
    withdrawn: 'Zurückgezogen oder erledigt',
    open: 'Noch offen',
  }.freeze

  # Fraktionen and their colours. A Drucksache counts for a Fraktion when its
  # title or author names it, so the figures are approximate.
  PARTIES = {
    'CDU' => '#222',
    'SPD' => '#dc3545',
    'Grüne' => '#28a745',
    'FDP' => '#ffc107',
    'Linke' => '#c535dc',
    'Volt' => '#502379',
    'AfD' => '#add8e6',
  }.freeze

  # Kinds of Drucksache counted per Fraktion. A kind with fewer than
  # MIN_PARTY_DOCUMENTS in all is left out: a chart of one or two is noise.
  PARTY_KINDS = {
    'Anträge' => :proposals,
    'Kleine Anfragen' => :small_inquiries,
    'Große Anfragen' => :large_inquiries,
  }.freeze
  MIN_PARTY_DOCUMENTS = 5

  attr_reader :district

  def initialize(district)
    @district = district
  end

  # The decision an agenda item records, as one of OUTCOMES, or nil when it
  # settles nothing: vertagt, überwiesen, zurückgestellt. "ungeändert
  # beschlossen / überwiesen" is a decision with a copy sent elsewhere.
  def self.outcome(decision)
    case decision
    when /abgelehnt/i then :rejected
    when /beschlossen/i then :adopted
    when /zurückgezogen|erledigt|zur Kenntnis/i then :withdrawn
    end
  end

  def documents
    Document.current_legislation(district)
  end

  def document_count
    @document_count ||= documents.count
  end

  def proposal_count
    proposal_outcomes.values.sum
  end

  def inquiry_count
    documents.small_inquiries.or(documents.large_inquiries).count
  end

  # The day of the legislation's first meeting, or nil before there was one.
  def start_date
    return @start_date if defined?(@start_date)

    @start_date = documents.joins(agenda_items: :meeting).minimum('meetings.date')
  end

  def meeting_count
    return 0 if start_date.nil?

    district.meetings.complete.where(date: start_date..Date.current).count
  end

  # All Drucksachen and the Anträge among them per month, each counted once,
  # in the month it first reached a meeting. Complete months only.
  def monthly_timeline
    return [] if start_date.nil?

    range = start_date.beginning_of_month...Date.current.beginning_of_month
    { 'Alle Drucksachen' => documents, 'Davon Anträge' => documents.proposals }.map do |name, scope|
      firsts = first_meetings(scope, before: range.end)
      data = Document.unscoped.from(firsts, :firsts)
                     .group_by_month('firsts.first_date', range:, format: method(:month_label)).count
      { name:, data: }
    end
  end

  # [Topic, count] pairs, most frequent first.
  def topic_counts
    @topic_counts ||= Topic.ranked(documents.topic_counts)
  end

  # One series per most frequent topic, Drucksachen per quarter, each counted
  # in the quarter it first reached a meeting. Complete
  # quarters only: the running one would always look like a drop.
  def topic_timeline
    topics = topic_counts.first(TIMELINE_TOPICS).map(&:first)
    return {} if topics.empty?

    firsts = first_meetings(documents, before: Date.current.beginning_of_quarter)
    tagged = Document.unscoped.from(firsts, :firsts).select('unnest(firsts.topics) AS topic, firsts.first_date')
    counts = Document.unscoped.from(tagged, :tagged).where(tagged: { topic: topics.map(&:key) })
                     .group('tagged.topic').group_by_quarter('tagged.first_date', format: method(:quarter_label)).count

    topics.map do |topic|
      { name: topic.label, data: counts.filter_map { |(key, quarter), count| [quarter, count] if key == topic.key }.to_h }
    end
  end

  # { outcome => number of Anträge }, every outcome present.
  def proposal_outcomes
    @proposal_outcomes ||= tally(proposals.keys)
  end

  # Share of the decided Anträge that were adopted, or nil before any decision.
  def adoption_rate
    decided = proposal_outcomes.values.sum - proposal_outcomes[:open]
    return nil if decided.zero?

    proposal_outcomes[:adopted].fdiv(decided)
  end

  # [Topic, { outcome => count }] for the topics with the most Anträge.
  def outcomes_by_topic
    by_topic = Hash.new { |hash, key| hash[key] = [] }
    proposals.each { |id, topics| topics.each { |key| by_topic[key] << id } }

    Topic.ranked(by_topic.transform_values(&:size))
         .select { |_topic, count| count >= MIN_PROPOSALS_PER_TOPIC }
         .first(OUTCOME_TOPICS)
         .map { |topic, _count| [topic, tally(by_topic[topic.key])] }
  end

  # [Quarter, count] for every Stadtteil of the district, most named first.
  def quarter_counts
    @quarter_counts ||= begin
      tagged = documents.select('unnest(documents.quarters) AS quarter')
      counts = Document.unscoped.from(tagged, :tagged).group('tagged.quarter').count

      Quarter.in_district(district.number).by_name.map { |quarter| [quarter, counts.fetch(quarter.name, 0)] }
             .sort_by { |quarter, count| [-count, quarter.name] }
    end
  end

  # One series per Fraktion, for a grouped chart over PARTY_KINDS.
  def party_series
    counts = PARTIES.keys.index_with do |party|
      PARTY_KINDS.transform_values { |scope| documents.public_send(scope).authored_by(party).count }
    end
    kinds = PARTY_KINDS.keys.select { |kind| counts.values.sum { |row| row[kind] } >= MIN_PARTY_DOCUMENTS }

    PARTIES.map { |party, color| { name: party, color:, data: counts[party].slice(*kinds) } }
  end

  private

  # One row per Drucksache in the scope with its topics and the date of the
  # first meeting before +before+ that discussed it, as first_date.
  def first_meetings(scope, before:)
    scope.joins(agenda_items: :meeting).where(meetings: { date: ...before })
         .group('documents.id').select('documents.topics, MIN(meetings.date) AS first_date')
  end

  # { Antrag id => its topic keys }
  def proposals
    @proposals ||= documents.proposals.pluck(:id, :topics).to_h
  end

  # { Antrag id => outcome }. The latest decision that settles the Antrag
  # counts, so a later "vertagt" in another committee does not reopen it.
  def outcomes
    @outcomes ||= begin
      decisions = AgendaItem.joins(:meeting).where(document_id: proposals.keys).where.not(decision: nil)
                            .order('meetings.date DESC, agenda_items.id DESC').pluck(:document_id, :decision)

      decisions.group_by(&:first).transform_values do |rows|
        rows.lazy.filter_map { |_id, decision| self.class.outcome(decision) }.first
      end
    end
  end

  def tally(ids)
    counts = OUTCOMES.keys.index_with(0)
    ids.each { |id| counts[outcomes[id] || :open] += 1 }
    counts
  end

  def month_label(date)
    I18n.l(date, format: '%b %y')
  end

  def quarter_label(date)
    "#{(date.month + 2) / 3}. Q. #{date.year}"
  end
end
