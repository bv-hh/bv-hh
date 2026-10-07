# frozen_string_literal: true

# Decides which topics a document is about from signals that are already in
# the data, without a model:
#
# - title:     a term of the topic in the title
# - body:      a term of the topic in the full text
# - committee: the document was on the agenda of a committee for the topic
# - poi:       a place linked to the document belongs to one of the topic's
#              POI categories, or the title names one (title_patterns: a park)
#
# A title hit is enough on its own. The others are weak: a long Mitteilung
# mentions many things in passing, a Mobilitätsausschuss also handles bus
# stops, and a school is also a polling station. Any two of them together are
# taken as a topic.
#
# The signals are kept separately so they can be counted and exported as weak
# labels for training a classifier later.
class TopicClassifier
  WEAK_SIGNALS = %i[body committee poi].freeze
  WEAK_SIGNALS_NEEDED = 2
  # A procedural title ("Benennung für den Ausschuss Bildung und Sport",
  # "Umbesetzung im Ausschuss für Umwelt und Gesundheit") names committees, and
  # committees are named after topics. In such a document the title only
  # speaks for this topic; the others need the weak signals.
  PROCEDURAL = 'gremien'

  attr_reader :document

  # Every committee name with "Ausschuss" in it, in the genitive too, as one
  # pattern. Names without it ("Mobilität") are ordinary words in a title.
  def self.committee_pattern
    @committee_pattern ||= begin
      names = Committee.where('name ILIKE ?', '%ausschuss%').distinct.pluck(:name)
      alternatives = names.sort_by { |name| -name.length }.map do |name|
        Regexp.escape(name).gsub(/ausschuss/i) { |word| "#{word}(?:es)?" }.gsub('\ ', '\s+')
      end
      alternatives.any? ? Regexp.new(alternatives.join('|'), Regexp::IGNORECASE) : /(?!)/
    end
  end

  def self.reset!
    @committee_pattern = nil
  end

  def initialize(document)
    @document = document
  end

  def topics
    found = signals.filter_map { |key, hits| key if topic?(hits, title: key == PROCEDURAL || !procedural?) }
    found.reject { |key| yielded?(key) }
  end

  # { topic_key => { title:, body:, committee:, poi: } }
  def signals
    @signals ||= Topic.to_h do |topic|
      [topic.key, {
        title: term_hits["title_#{topic.key}"] == true,
        body: term_hits["body_#{topic.key}"] == true,
        committee: committee_names.any? { |name| topic.committee?(name) },
        poi: topic.poi_categories.intersect?(poi_categories) || topic.title_pattern?(cased_title),
      }]
    end
  end

  private

  def topic?(found, title:)
    (title && found[:title]) || WEAK_SIGNALS.count { |signal| found[signal] } >= WEAK_SIGNALS_NEEDED
  end

  # A topic yields to another whose terms are in the title: a title about
  # Tempo 30 in front of a school is about traffic, and the school is where.
  # Unless one of its yields_unless terms is in the title too: a barrier-free
  # crossing is about Barrierefreiheit.
  def yielded?(key)
    return false if term_hits["holds_#{key}"] == true

    Topic.find(key).yields_to.any? { |other| signals.dig(other, :title) }
  end

  def procedural?
    signals.dig(PROCEDURAL, :title)
  end

  # One query for every topic: the title and the full text are turned into a
  # tsvector once and matched against each topic's terms.
  def term_hits
    @term_hits ||= begin
      connection = Document.connection
      columns = Topic.flat_map do |topic|
        [match_column('title_vector', topic.title_tsquery, "title_#{topic.key}"),
         match_column('body_vector', topic.body_tsquery, "body_#{topic.key}"),
         match_column('title_vector', topic.yields_unless_tsquery, "holds_#{topic.key}")]
      end

      sql = <<~SQL.squish
        WITH vectors AS (
          SELECT to_tsvector('german', #{connection.quote(matchable_title)}) AS title_vector,
                 to_tsvector('german', #{connection.quote(matchable_body)}) AS body_vector
        )
        SELECT #{columns.join(', ')} FROM vectors
      SQL

      connection.select_one(sql) || {}
    end
  end

  def match_column(vector, tsquery, name)
    return "false AS #{name}" if tsquery.nil?

    "(#{vector} @@ to_tsquery('german', #{Document.connection.quote(tsquery)})) AS #{name}"
  end

  # The title without the committee it comes from ("… Beschlussvorlage des
  # Ausschusses für Haushalt und Kultur"), street names ("Schulstraße") and
  # stations ("Toiletten am S-Bahnhof Neuwiedenthal"): all name a topic the
  # document is not about.
  def matchable_title
    TransitGazetteer.remove(StreetGazetteer.remove(cased_title))
  end

  # The title without committee names, in its own case for title_patterns:
  # the gazetteers fold it.
  def cased_title
    @cased_title ||= document.title.to_s.gsub(self.class.committee_pattern, ' ')
  end

  # The full text without committee names, for the same reason: "der Ausschuss
  # für Grün, Naturschutz und Sport hat sich befasst" is not about sport, and
  # every Mitteilung names the committee it goes to.
  def matchable_body
    document.full_text.to_s.gsub(self.class.committee_pattern, ' ')
  end

  # A Regionalausschuss handles every topic of its area, so it says nothing
  # about the document.
  def committee_names
    @committee_names ||= document.committees.distinct.reject(&:local?).map(&:name)
  end

  # Locations resolved to a POI carry its place_key ("osm:node/123") as
  # place_id, which leads back to the POI and its category.
  def poi_categories
    @poi_categories ||= begin
      place_ids = document.locations.where('locations.place_id LIKE ?', 'osm:%').pluck(:place_id)
      osm_ids = place_ids.map { |place_id| place_id.split('/').last.to_i }
      Poi.where(osm_id: osm_ids).select { |poi| place_ids.include?(poi.place_key) }.map(&:category).uniq
    end
  end
end
