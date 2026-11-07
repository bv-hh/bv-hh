# frozen_string_literal: true

# The Drucksachen closest in meaning to a document, from its own Bezirk and
# the others, by the cosine distance of their DocumentEmbeddings. Answers "was
# this already asked for elsewhere?", which a search for words misses when
# another Bezirk put it differently.
#
# Each Bezirk has recurring series and templates (Quartiersfonds, Fällliste,
# Arbeitsprogramm 2021, 2022, …) that lie much closer to each other than
# anything from another Bezirk, and subtracting each Bezirk's mean vector
# doesn't change that. So the own Bezirk and the others get separate places in
# the list, instead of competing for the closest five.
#
# Leaves out the document's own family (the same number with or without a
# suffix such as 22-1234.1, already listed as Verwandte Drucksachen), more
# than one member of another family, and what the caller passes as exclude, so
# a document listed for another reason isn't shown twice.
class SimilarDocuments
  # e5 puts nearly all German text within a narrow band of distances. On 400
  # random documents, the closest one from another Bezirk was under 0.105 for a
  # quarter of them and nearly always on the same matter; above 0.115 it
  # rarely was.
  MAX_DISTANCE = 0.11
  SAME_DISTRICT = 2
  OTHER_DISTRICTS = 3
  # Fetched from the index before filtering, and the HNSW search width needed
  # to return that many. The own Bezirk fills the first few hundred; at 400,
  # 97 % of the closest five from elsewhere are found that an exact search
  # finds, in about 12 ms instead of 150.
  CANDIDATES = 400
  # New documents are embedded nightly, so a day old is recent enough.
  CACHE_FOR = 1.day

  def initialize(document, exclude: [])
    @document = document
    @exclude = exclude.to_set
  end

  def to_a
    @to_a ||= records(Rails.cache.fetch(cache_key, expires_in: CACHE_FOR) { find })
  end

  private

  def records(ids)
    return [] if ids.empty?

    # A document hidden or deleted since the ids were picked is missing here.
    Document.for_list.where(id: ids).index_by(&:id).values_at(*ids).compact
  end

  # The ids to show, closest first.
  def find
    distances = candidates
    return [] if distances.empty?

    rows = Document.complete.where(id: distances.keys).pluck(:id, :district_id, :number).index_by(&:first)
    pick(distances.keys.filter_map { |id| rows[id] })
  end

  # A changed text gets a new digest and so a new entry.
  def cache_key
    digest = @document.embedding&.digest
    ['similar_documents', @document.id, digest, Digest::MD5.hexdigest(@exclude.sort.join(','))].join('/')
  end

  # Ids of the closest, as many as each side may have, one per family, from
  # [id, district_id, number] closest first. Only these are loaded in full.
  def pick(rows)
    families = Set[family(@document.id, @document.district_id, @document.number)]
    left = { true => SAME_DISTRICT, false => OTHER_DISTRICTS }
    rows.filter_map do |id, district_id, number|
      same = district_id == @document.district_id
      next if @exclude.include?(id) || left[same].zero? || !families.add?(family(id, district_id, number))

      left[same] -= 1
      id
    end
  end

  # Document ids to their distance, closest first and within MAX_DISTANCE.
  def candidates
    embedding = @document.embedding
    return {} if embedding.nil? || embedding.model != DocumentEmbedder::NAME

    # Ordered by the alias, so the distance is computed once per row; it is
    # still an HNSW index scan. Not neighbor's nearest_neighbors, which
    # computes it twice and builds a record per row: half as fast again.
    distance = DocumentEmbedding.sanitize_sql_array(['embedding <=> ?::vector AS distance', "[#{embedding.embedding.join(',')}]"])
    query = DocumentEmbedding.where(model: DocumentEmbedder::NAME).where.not(document_id: @document.id)
                             .select(:document_id, Arel.sql(distance)).order(:distance).limit(CANDIDATES)
    connection = DocumentEmbedding.connection
    rows = DocumentEmbedding.transaction do
      connection.execute("SET LOCAL hnsw.ef_search = #{CANDIDATES}")
      connection.select_rows(query.to_sql)
    end
    rows.filter_map { |id, value| [id, value.to_f] if value.to_f <= MAX_DISTANCE }.to_h
  end

  # A document without a number is a family of its own.
  def family(id, district_id, number)
    [district_id, number.presence&.split('.')&.first || "id #{id}"]
  end
end
