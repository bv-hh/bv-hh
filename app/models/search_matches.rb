# frozen_string_literal: true

# What a search term names, besides the words it finds in documents: a
# Stadtteil, a street or a topic. The search page offers these above the
# results, since the search field invites exactly such terms.
#
# Only the whole term counts, and only names the registers know. "Ottensen"
# is the Stadtteil; "Radweg Ottensen" is a full-text search and nothing else.
class SearchMatches
  StreetMatch = Data.define(:name, :quarters)

  attr_reader :quarter, :street, :topic

  def initialize(term)
    term = term.to_s.squish
    return if term.blank?

    @quarter = find_quarter(term)
    @street = find_street(term)
    @topic = find_topic(term)
  end

  def any?
    [quarter, street, topic].any?
  end

  private

  # A Quarter without a District has no page to link to.
  def find_quarter(term)
    quarter = Quarter.lookup(term)
    quarter if quarter&.district
  end

  # A street name can recur in several Bezirke, and a long street crosses
  # several Stadtteile. Either way it is one street to the user, the way the
  # feed treats it.
  def find_street(term)
    streets = Street.where(normalized_name: Street.normalize(term)).to_a
    return if streets.empty?

    quarters = streets.flat_map(&:quarters).uniq.sort.filter_map { |name| Quarter.lookup(name) }.select(&:district)
    StreetMatch.new(name: streets.first.name, quarters:)
  end

  # By slug, or by one part of the label: "Radverkehr", but also "Bäume" for
  # "Grün, Parks & Bäume".
  def find_topic(term)
    Topic.lookup(term.parameterize) ||
      Topic.all.find { |topic| topic.label.split(/\s*[,&]\s*/).any? { |part| part.casecmp?(term) } }
  end
end
