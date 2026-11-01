# frozen_string_literal: true

# Imports the Bürgerschaft's Drucksachen of a period from ParlDok as
# Proceedings, and keeps the open ones up to date. Resumable: a Drucksache
# already imported costs nothing but its line in the list, and a PDF that could
# not be read is tried again next run.
#
# A run does, in this order, as far as its deadline allows:
#
#   1. every Drucksache of the period not imported yet, and every one that has
#      been given a Vorgang since it was imported alone
#   2. the PDFs not read yet
#   3. the open Vorgänge not checked for REFRESH_AFTER, where the Bürgerschaft
#      may have decided since: a decision in the plenary brings no Drucksache
#      that step 1 would see
#   4. the PDFs step 3 brought
#
# A Drucksache or Vorgang ParlDok cannot answer for is reported and skipped, so
# one broken record cannot hold up every run after it. When ParlDok cannot be
# reached at all the run ends.
class ProceedingImporter
  CURRENT_PERIOD = 23
  # What is imported at all: the current Wahlperiode and the one before, most
  # recent first. Older ones say little about places as they are today.
  PERIODS = [CURRENT_PERIOD, CURRENT_PERIOD - 1].freeze

  # The types that can be about a place. Wahlvorschläge, Gesetzentwürfe and
  # Bekanntmachungen are not; a Gesetzentwurf still comes along as a paper
  # when it is part of a Vorgang.
  KINDS = [
    'Schriftliche Kleine Anfrage',
    'Große Anfrage',
    'Antrag',
    'Bericht',
    'Ausschussbericht',
  ].freeze

  # Where nothing follows any more, as ParlDok's Beratungsstand names it.
  # Annahme is not among them: an accepted Ersuchen is answered by the Senat
  # later, in the same Vorgang.
  SETTLED_STATES = [
    'Ablehnung',
    'Kenntnisnahme',
    'zurückgezogen',
    'für erledigt erklärt',
    'erledigt durch Ablauf der Wahlperiode',
    'Verkündung im GVBl',
  ].freeze

  REFRESH_AFTER = 7.days

  def initialize(client = ParldokClient.new)
    @client = client
  end

  # The number of Drucksachen imported. Stops at +deadline+, if given. Only the
  # current period is refreshed: in a closed one nothing is open any more.
  def import!(period = CURRENT_PERIOD, deadline: nil)
    raise ArgumentError, "period #{period} is not among #{PERIODS.join(', ')}" unless PERIODS.include?(period)

    @deadline = deadline
    count = import_hits(period)
    fetch_texts!
    return count unless period == CURRENT_PERIOD

    count += refresh!(period)
    fetch_texts!
    count
  end

  # Fetches the PDFs not read yet, and updates the text of their proceedings.
  def fetch_texts!
    ProceedingPaper.without_text.includes(:proceeding).find_each do |paper|
      break if out_of_time?

      text = skipping_failure(paper.parldok_id) { @client.text(paper.parldok_id) }
      next if text.nil?

      paper.update!(full_text: text)
      paper.proceeding.update_text!
    end
  end

  # The open Vorgänge of +period+ asked for again, least recently checked
  # first. The number of Drucksachen they brought.
  def refresh!(period)
    count = 0
    stale(period).each do |proceeding|
      break if out_of_time?

      parldok_id = proceeding.papers.first&.parldok_id
      next if parldok_id.nil?

      vorgang = skipping_failure(parldok_id) { @client.vorgang(parldok_id) }
      if vorgang
        count += import_vorgang(vorgang)
      else
        proceeding.update!(checked_at: Time.current)
      end
    end
    count
  end

  private

  def import_hits(period)
    count = 0
    @client.each_page(period) do |hits|
      break if out_of_time?

      hits = hits.select { |hit| KINDS.include?(hit.kind) && hit.drucksache }
      known = ProceedingPaper.where(parldok_id: hits.map(&:parldok_id)).includes(:proceeding).index_by(&:parldok_id)
      hits.each do |hit|
        break if out_of_time?
        next unless due?(hit, known[hit.parldok_id])

        count += skipping_failure(hit.parldok_id) { import_hit(hit) }.to_i
      end
    end
    count
  end

  # New, or imported alone and since given a Vorgang: an Antrag is filed
  # before it is referred.
  def due?(hit, paper)
    paper.nil? || (hit.process_id.present? && paper.proceeding.parldok_process_id.nil?)
  end

  # A Drucksache of a Vorgang brings the whole Vorgang along: its other
  # Drucksachen, its steps and where it stands.
  def import_hit(hit)
    vorgang = @client.vorgang(hit.parldok_id) if hit.process_id
    return import_vorgang(vorgang) if vorgang
    return 0 if ProceedingPaper.exists?(parldok_id: hit.parldok_id)

    Proceeding.transaction do
      proceeding = Proceeding.create!(period: hit.period, number: hit.number, title: hit.title, date: hit.date)
      store_paper(proceeding, hit)
    end
  end

  # The Vorgang may be known already, from an earlier Drucksache of it.
  def import_vorgang(vorgang)
    Proceeding.transaction do
      proceeding = Proceeding.find_or_initialize_by(parldok_process_id: vorgang.id)
      proceeding.update!(period: vorgang.period, number: vorgang.number, title: vorgang.title,
                         abstract: vorgang.abstract, state: vorgang.state, steps: vorgang.steps,
                         date: vorgang.hits.filter_map(&:date).max, checked_at: Time.current)
      vorgang.hits.select(&:drucksache).sum { |hit| store_paper(proceeding, hit) }
    end
  end

  # 1 if the paper is new. A paper imported on its own before its Vorgang
  # existed moves to the Vorgang, and the proceeding it leaves behind empty
  # goes.
  def store_paper(proceeding, hit)
    paper = ProceedingPaper.find_or_initialize_by(parldok_id: hit.parldok_id)
    created = paper.new_record?
    previous = paper.proceeding unless created || paper.proceeding_id == proceeding.id

    paper.update!(proceeding:, period: hit.period, number: hit.number, kind: hit.kind, title: hit.title,
                  date: hit.date)
    if previous
      previous.papers.reload.empty? ? previous.destroy! : previous.update_text!
      proceeding.update_text!
    end

    created ? 1 : 0
  end

  def stale(period)
    open = Proceeding.where(state: nil).or(Proceeding.where.not(state: SETTLED_STATES))
    Proceeding.where(period:).where.not(parldok_process_id: nil).merge(open)
              .where(checked_at: ...REFRESH_AFTER.ago)
              .order(:checked_at, :id)
  end

  def skipping_failure(parldok_id)
    yield
  rescue ParldokClient::Error => e
    Rails.error.report(e, handled: true, context: { parldok_id: })
    nil
  end

  def out_of_time?
    @deadline.present? && Time.current > @deadline
  end
end
