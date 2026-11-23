# frozen_string_literal: true

# Reads the decision of an agenda item from its result and minutes, for the
# items ALLRIS leaves "(offen)". Some committees, Bergedorf's above all, write
# the decision only into the text: "Der Ausschuss beschließt einstimmig."
#
# Only a sentence that names the body or the vote counts ("Der Ausschuss
# lehnt den Antrag ab", "Abstimmungsergebnis: einstimmig beschlossen"), not
# what a member says or what happened elsewhere ("Herr X lehnt das ab", "der
# Antrag sei abgelehnt worden"). The last such sentence decides, as minutes
# end with the vote; the result text goes first where it has one.
class MinutesDecision
  # Ordered: the first pattern a decision sentence matches gives its outcome.
  # "beschließt den so geänderten Antrag" is amended before adopted, and
  # "beschließt … und überweist ihn" adopted before referred, as ALLRIS counts
  # "ungeändert beschlossen / überwiesen" as adopted.
  RULES = [
    [:withdrawn, /\bzurückgezogen\b|\bzieht\b.{0,80}\bzurück\b|\bfür erledigt erklärt\b/i],
    [:deferred, /\bzurückgestellt\b/i],
    [:postponed, /\bvertagt\b|\bvertagen\b|\bverbleibt im (Ausschuss|Gremium)\b/i],
    [:noted, /\bzur Kenntnis\b|\bnimmt\b.{0,80}\bKenntnis\b|\bnehmen\b.{0,80}\bKenntnis\b|\bKenntnisnahme\b/i],
    [:rejected, /\babgelehnt\b|\blehnt\b.{0,120}\bab\b|\bkeine Mehrheit\b/i],
    [:amended, /\bso geänderten?\b|\bgeänderter Fassung\b|\bmit (der|den|folgender|folgenden) Änderung|\bgeändert(e|en)? (beschlossen|angenommen|zugestimmt)\b/i],
    [:adopted, /\bbeschlie(ß|ss)t\b|\bbeschlossen\b|\bangenommen\b|\bstimmt\b.{0,120}\bzu\b|\bzugestimmt\b/i],
    [:referred, /\büberweist\b|\büberwiesen\b|\bverweist\b|\bverwiesen\b/i],
  ].freeze

  # Who or what a decision sentence is about.
  BODY = /\b(Ausschuss|Ausschusses|Bezirksversammlung|Gremium|Antrag|Anträge|Vorlage|Drucksache|Anfrage|Mitteilung|Beschlussempfehlung|Petitum|Abstimmungsergebnis|Ergebnis|einstimmig|mehrheitlich|einvernehmlich|Mitglieder)\b/i

  # Reported speech, the past, negation, parts of a motion and procedural
  # votes ("lehnt die Überweisung ab", "Der Alternativantrag findet keine
  # Mehrheit"): about something other than this item's vote.
  NOT_THE_VOTE = Regexp.union(
    /\b(sei|seien|habe|hätte|wäre|würde|werde|wurde|wurden|worden|bereits|damals|erklärt|berichtet|nicht)\b/i,
    /\b(Änderungsantrag|Änderungsanträge|Zusatzantrag|Alternativantrag|Gegenantrag|Geschäftsordnungsantrag|Vorschlag)\b/i,
    /\b(Ziffer|Ziffern|Punkt|Punkte|Petitumspunkt|Absatz|Überweisung|Zurückstellung|Vertagung|Dringlichkeit|Verfahrensvorschlag)\b/i,
    /\bAntrag (von|auf|des Herrn|der Frau)\b|\baus der Sitzung\b|\?/i
  )

  # A member as the subject: what one person says or does, not the vote.
  # A mover withdrawing the Antrag is the exception ("Herr X zieht den
  # Antrag zurück").
  PERSON = /\A(Herr|Frau)\s|\b(Herr|Frau)\s+\S+\s+(\([^)]*\)\s+)?(stimmt|lehnt|beschließt|nimmt|überweist|vertagt)\b/

  SENTENCE = /(?<=[.!:])\s+(?=[A-ZÄÖÜ])|\n+/
  # A full stop after these does not end a sentence.
  ABBREVIATION = /\b(Drs|Nr|bzw|ca|vgl|Abs|Ziff|gem|z\.B|u\.a|Hr|Fr|lfd|bez|S)\.\z/

  def self.outcome(agenda_item)
    new(agenda_item).outcome
  end

  def initialize(agenda_item)
    @agenda_item = agenda_item
  end

  def outcome
    [@agenda_item.result, @agenda_item.minutes].each do |html|
      sentence = decision_sentences(Parsing.text(html)).last
      return outcome_of(sentence) if sentence
    end
    nil
  end

  private

  def decision_sentences(text)
    sentences(text.to_s).select do |sentence|
      outcome = outcome_of(sentence)
      outcome && sentence.match?(BODY) && !sentence.match?(NOT_THE_VOTE) && !about_another_drucksache?(sentence) &&
        (outcome == :withdrawn || !sentence.match?(PERSON))
    end
  end

  # Names a Drucksache outside its own family: the vote on another item,
  # as when a Bezirksversammlung decides several under one TOP.
  def about_another_drucksache?(sentence)
    family = @agenda_item.document&.number.to_s.split('.').first
    Document.references_in(sentence, nil).any? { |number| number.split('.').first != family }
  end

  def outcome_of(sentence)
    RULES.find { |_outcome, pattern| sentence.match?(pattern) }&.first
  end

  def sentences(text)
    text.split(SENTENCE).each_with_object([]) do |part, joined|
      if joined.last&.match?(ABBREVIATION)
        joined[-1] = "#{joined.last} #{part}"
      else
        joined << part.squish
      end
    end
  end
end
