# frozen_string_literal: true

# Parses the attendance list from a `pdftotext -layout` rendering of an ALLRIS
# meeting protocol (Niederschrift).
#
# The formatting varies between the seven Hamburg districts:
#   * rows may sit at column 0 or be indented by a space (Altona);
#   * names may be "Herr/Frau <Nachname>" or full "Herr/Frau <Vorname> <Nachname>"
#     (Wandsbek, Harburg);
#   * the Funktion may be an explicit column ("Ausschussmitglied", "Ständige
#     Vertretung") or only implied by the section header ("stellvertretende
#     Mitglieder", "Mitglieder ohne Stimmrecht");
#   * substitutions may be flagged inline ("für Frau X"), by a role ("Ständige
#     Vertretung") or by a whole section ("stellvertretende Mitglieder").
#
# We only need the surname (first cell of the row), the party, the role and
# whether the person stood in for someone, so instead of reconstructing the
# columns we scan each person's combined text and its section for those tokens.
# Administrative sections (Verwaltung, Protokollführung, guests, ...) are
# ignored; entries carry a +present+ flag (false for excused/absent sections).
class AttendanceExtractor
  Entry = Struct.new(:name, :surname, :party, :role, :section, :substitute, :present, keyword_init: true)

  SALUTATIONS = %w[Herr Frau].freeze
  TITLES = %w[Dr. Prof. Dipl. Dr Prof].freeze

  # Normalised party token => matcher against the free-text Fraktion.
  PARTIES = {
    'GRÜNE' => /grün/i,
    'SPD' => /\bspd\b/i,
    'CDU' => /\bcdu\b/i,
    'LINKE' => /linke/i,
    'FDP' => /\bfdp\b/i,
    'AfD' => /\bafd\b/i,
    'VOLT' => /\bvolt\b/i,
    'PIRATEN' => /piraten/i,
  }.freeze

  # Longest first so e.g. "Stellvertr. Ausschussmitglied" wins over "Ausschussmitglied".
  ROLES = [
    'Vorsitzendes Mitglied', 'Stellvertr. Vorsitz', 'Stellv. Vorsitz', 'Ständige Vertretung',
    'Stellvertr. Ausschussmitglied', 'Stellvertr. Mitglied', 'Ausschussmitglied',
    'Bezirksversammlungsmitglied', 'Seniorenbeiratsmitglied', 'Beratendes Mitglied'
  ].freeze

  SKIP_SECTION = /\A(Verwaltung|Protokoll|Schriftf|Gäste|Gast|Referent|Presse|Öffentlichk|Bürgerfrage)/i
  ABSENT_SECTION = /fehlt|entschuldigt|abwesend|nicht anwesend/i
  PRESENT_SECTION = /Vorsitz|Mitglied|Mitwirk|Vertret|Teilnehm|anwesend|sachkundig|Bürgerdep/i

  SUBSTITUTE_TEXT = /\bfür:?\s+(?:Herr|Frau)\b/i
  SUBSTITUTE_ROLE = /ständige vertretung|stellvertretende?\s+mitglied/i
  ROW = /\A(Herr|Frau)\s+\p{L}/
  PAGE_MARKER = %r{\ASeite:\s*\d+/\d+}
  # The attendance list always precedes the agenda / minutes body; stop there so
  # names quoted in the discussion are not mistaken for attendees.
  AGENDA_START = /\AÖffentlicher Teil|\ANicht.?öffentlicher Teil/i

  def initialize(text)
    @text = text.to_s
  end

  def entries
    @entries = []
    @mode = nil
    @section = nil
    @section_party = nil
    @current = nil

    @text.each_line do |raw|
      line = raw.rstrip
      stripped = line.strip
      next if stripped.empty? || stripped.match?(PAGE_MARKER)
      break if agenda_start?(stripped)

      handle(line, stripped)
    end
    push_current

    @entries
  end

  private

  def handle(line, stripped)
    if stripped.match?(ROW)
      push_current
      @current = row(stripped) if member_section?
    elsif !indented?(line) && (token = party_header(stripped))
      push_current
      @section_party = token
    elsif !indented?(line) && (section = classify(stripped))
      push_current
      @mode, @section = section
      @section_party = nil
    elsif @current && indented?(line)
      @current[:lines] << stripped
    else
      push_current
    end
  end

  def row(stripped)
    { name: stripped, lines: [stripped], present: @mode == :present, section: @section, party: @section_party }
  end

  # Some districts (Hamburg-Mitte) group members under a bare party sub-header
  # ("CDU", "DIE LINKE", ...) instead of naming the party in each row.
  def party_header(phrase)
    return if phrase.match?(/\s{2,}/) || classify(phrase)

    detect_party(phrase)
  end

  def indented?(line)
    line.start_with?(' ', "\t")
  end

  def agenda_start?(stripped)
    stripped.delete(' ').match?(/\ATagesordnung/i) || stripped.match?(AGENDA_START)
  end

  def member_section?
    @mode == :present || @mode == :absent
  end

  # A section header is a single-phrase line (no multi-column layout).
  def classify(phrase)
    return if phrase.match?(/\s{2,}/)
    return [:absent, phrase] if phrase.match?(ABSENT_SECTION)
    return [:skip, phrase] if phrase.match?(SKIP_SECTION)
    return [:present, phrase] if phrase.match?(PRESENT_SECTION)

    nil
  end

  def push_current
    return if @current.nil?

    entry = build(@current)
    @entries << entry if entry
    @current = nil
  end

  def build(row)
    name = row[:name].split(/\s{2,}/).first.strip
    surname = surname_of(name)
    return if surname.blank?

    combined = row[:lines].join(' ')
    role = detect_role(combined) || row[:section]
    Entry.new(name: name, surname: surname, party: detect_party(combined) || row[:party],
              role: role, section: row[:section], substitute: substitute?(combined, role, row[:section]),
              present: row[:present])
  end

  def surname_of(name_cell)
    tokens = name_cell.split
    tokens.shift if SALUTATIONS.include?(tokens.first)
    tokens -= TITLES
    tokens.last
  end

  def detect_party(text)
    PARTIES.find { |_token, matcher| text.match?(matcher) }&.first
  end

  def detect_role(text)
    ROLES.find { |role| text.include?(role) }
  end

  def substitute?(combined, role, section)
    combined.match?(SUBSTITUTE_TEXT) || "#{role} #{section}".match?(SUBSTITUTE_ROLE)
  end
end
