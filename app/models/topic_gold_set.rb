# frozen_string_literal: true

# A fixed sample of documents with hand-checked topics, against which the rules
# (and later a classifier) are measured. See db/gold/README.md for how it is
# labelled.
#
# The set lives in db/gold/topics.jsonl, one entry per line:
#
#   {"district":"hamburg-nord","number":"22-1234","stratum":"random","topics":["radverkehr"],"labeler":"claude"}
#
# A document is identified by district and number rather than by id, so the file
# means the same in development and production. topics is null until the
# document is labelled, [] when no topic applies.
#
# The sample has three strata, recorded per entry:
#
#   random   — uniform over the corpus: the only unbiased base for recall and
#              for how often a topic occurs at all
#   topic    — documents the rules tag with a topic, a few per topic, so that
#              rare topics have enough cases for precision
#   untagged — documents the rules tag with nothing, where misses concentrate
#
# There are three sets. The tuning set is what rule changes are read from and
# measured against, so its numbers flatter the rules once they have been tuned
# on it. The test set (db/gold/topics_test.jsonl) is random documents only,
# none of them in the tuning set, and is never used to change a rule: it is the
# honest number, for the rules and later for a classifier. The calibration set
# (db/gold/topics_calibration.jsonl), random documents in neither of the
# others, is where TopicTrainer chooses each topic's threshold.
class TopicGoldSet
  PATH = Rails.root.join('db/gold/topics.jsonl')
  TEST_PATH = Rails.root.join('db/gold/topics_test.jsonl')
  CALIBRATION_PATH = Rails.root.join('db/gold/topics_calibration.jsonl')
  SETS = { 'tuning' => PATH, 'test' => TEST_PATH, 'calibration' => CALIBRATION_PATH }.freeze
  STRATA = %w[random topic untagged].freeze
  LABELERS = %w[claude human].freeze
  TEXT_LENGTH = 3000

  Entry = Struct.new(:district, :number, :stratum, :topics, :labeler, keyword_init: true) do
    def key
      "#{district}/#{number}"
    end

    def labelled?
      !topics.nil?
    end

    def to_json(*)
      to_h.to_json(*)
    end
  end

  attr_reader :path, :entries

  def self.path_for(name)
    SETS.fetch(name.to_s) { raise ArgumentError, "unknown gold set #{name}, known: #{SETS.keys.join(', ')}" }
  end

  def self.load(path = PATH)
    entries = File.exist?(path) ? File.readlines(path, chomp: true).compact_blank.map { |line| Entry.new(**JSON.parse(line)) } : []
    new(entries, path)
  end

  # Draws a new sample. Refuses to replace one that exists: its labels are the
  # work this whole thing is for. Not reproducible, and need not be: the drawn
  # set is committed.
  # exclude: keys ("district/number") that must not be drawn, such as the
  # tuning set when drawing the test set.
  def self.sample(random: 150, per_topic: 8, untagged: 30, path: PATH, exclude: [])
    raise ArgumentError, "#{path} exists; delete it to draw a new sample" if File.exist?(path)

    new([], path).tap do |set|
      set.draw(random:, per_topic:, untagged:, exclude:)
      set.save
    end
  end

  def initialize(entries, path = PATH)
    @entries = entries
    @path = Pathname(path)
  end

  def draw(random:, per_topic:, untagged:, exclude: [])
    @excluded = exclude.to_set
    add(population.order(Arel.sql('random()')), 'random', random)
    Topic.each { |topic| add(population.with_topics(topic.key).order(Arel.sql('random()')), 'topic', per_topic) }
    add(population.where(topics: []).order(Arel.sql('random()')), 'untagged', untagged)
  end

  def save
    FileUtils.mkdir_p(path.dirname)
    File.write(path, "#{entries.map(&:to_json).join("\n")}\n")
  end

  def unlabelled
    entries.reject(&:labelled?)
  end

  def labelled
    entries.select(&:labelled?)
  end

  # { entry => document } for the given entries, looked up in this database.
  # Entries whose document is not here (another environment's newer documents)
  # are left out.
  def documents(of = entries)
    districts = District.all.index_by(&:to_param)
    of.filter_map do |entry|
      district = districts[entry.district]
      document = district && Document.complete.find_by(district:, number: entry.number)
      [entry, document] if document
    end.to_h
  end

  # Markdown files with the unlabelled documents to read, batch_size to a file,
  # and nothing about what the rules made of them: labelling is blind. Shuffled,
  # because the set is in stratum order, and a batch of the topic stratum would
  # otherwise be one topic after another.
  def write_texts(dir, batch_size: 25)
    FileUtils.mkdir_p(dir)
    FileUtils.rm_f(Dir[File.join(dir, 'batch-*.md')])
    documents(unlabelled).to_a.shuffle(random: Random.new(1)).each_slice(batch_size).with_index(1).map do |batch, index|
      file = Pathname(dir).join(format('batch-%02d.md', index))
      File.write(file, batch.map { |entry, document| text(entry, document) }.join("\n---\n\n"))
      file
    end
  end

  # Reads "district/number: key, key" lines ("-" for none) into the set. Every
  # line is checked before anything changes. Labels by a human are never
  # replaced by another labeler.
  def import(lines, labeler:)
    raise ArgumentError, "unknown labeler #{labeler}" unless LABELERS.include?(labeler)

    by_key = entries.index_by(&:key)
    parsed = lines.map(&:strip).reject { |line| line.empty? || line.start_with?('#') }.map { |line| parse(line, by_key) }

    parsed.count do |entry, topics|
      next false if entry.labeler == 'human' && labeler != 'human'

      entry.topics = topics
      entry.labeler = labeler
      true
    end
  end

  private

  def parse(line, by_key)
    key, value = line.split(':', 2).map(&:strip)
    entry = by_key[key] or raise ArgumentError, "not in the gold set: #{key}"
    topics = value == '-' ? [] : value.to_s.split(',').map(&:strip)
    unknown = topics - Topic.keys
    raise ArgumentError, "#{key}: unknown topics #{unknown.join(', ')}" if unknown.any?

    [entry, topics.sort]
  end

  def population
    Document.complete.where.not(full_text: [nil, ''])
  end

  # Adds up to count of the documents, skipping those already in the set or
  # excluded. Over-fetches by the number that could be skipped, so the count is
  # reached whenever the population allows it.
  def add(documents, stratum, count)
    return if count.zero?

    taken = entries.to_set(&:key) | @excluded
    added = 0
    # to_a, not find_each: find_each drops the random order and the limit.
    documents.includes(:district).limit(count + taken.size).to_a.each do |document|
      entry = Entry.new(district: document.district.to_param, number: document.number, stratum:, topics: nil, labeler: nil)
      next if taken.include?(entry.key)

      entries << entry
      taken << entry.key
      break if (added += 1) == count
    end
  end

  def text(entry, document)
    committees = document.committees.distinct.pluck(:name)
    body = document.full_text.to_s.squish
    body = "#{body.first(TEXT_LENGTH)} […]" if body.length > TEXT_LENGTH

    <<~MD
      ## #{entry.key}

      **#{document.title.to_s.squish}**
      #{document.kind}#{" · #{committees.join(', ')}" if committees.any?}

      #{body}
    MD
  end
end
