# frozen_string_literal: true

require 'csv'

namespace :topics do
  # After a bump of Topic::VERSION, and once for the initial backfill. New and
  # reparsed documents get their topics through AssignDocumentLocationsJob.
  desc 'Enqueue topic assignment for documents classified by an older Topic::VERSION'
  task :reassign, [:district] => :environment do |_task, args|
    documents = Document.complete.topics_outdated
    documents = documents.where(district: District.find_by!(name: args[:district])) if args[:district]

    count = 0
    documents.find_each do |document|
      document.assign_topics_later!
      count += 1
    end

    puts "Enqueued #{count} documents"
  end

  # Read-only. The stored topics of the corpus, and which signal carries each
  # topic on a random sample: a topic that only ever comes from its title has
  # weak rules for the other signals, one that is mostly body + committee may be
  # too loose.
  desc 'Show how often each topic is assigned, and by which signals'
  task :coverage, [:sample] => :environment do |_task, args|
    documents = Document.complete
    classified = documents.where(topics_version: Topic::VERSION)
    total = classified.count
    counts = classified.pluck(Arel.sql('unnest(topics)')).tally
    untagged = classified.where(topics: []).count

    puts "#{total} of #{documents.count} documents classified by version #{Topic::VERSION}, " \
         "#{untagged} without a topic"
    Topic.each do |topic|
      count = counts.fetch(topic.key, 0)
      puts format('%<count>6d  %<share>5.1f%%  %<label>s', count: count, share: 100.0 * count / [total, 1].max,
                                                           label: topic.label)
    end

    size = (args[:sample] || 500).to_i
    tally = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    documents.order('random()').limit(size).each do |document|
      TopicClassifier.new(document).signals.each do |key, found|
        found.each { |signal, hit| tally[key][signal] += 1 if hit }
      end
    end

    puts "\nSignals on #{size} random documents (title body committee poi):"
    Topic.each do |topic|
      hits = tally[topic.key]
      puts [*hits.values_at(:title, :body, :committee, :poi).map { |count| count.to_s.rjust(5) }, ' ', topic.label].join(' ')
    end
  end

  # For reading the results by hand: recent documents tagged with a topic.
  desc 'Print recent documents tagged with a topic'
  task :sample, %i[topic count] => :environment do |_task, args|
    topic = Topic.find(args[:topic]) or abort "Unknown topic. Known: #{Topic.keys.join(', ')}"

    Document.where('documents.topics @> ARRAY[?]::varchar[]', topic.key).latest_first
            .limit((args[:count] || 30).to_i).each do |document|
      puts "#{document.number.to_s.ljust(12)} #{document.title.to_s.truncate(140)}"
    end
  end

  # The weak labels with the signals behind them, as CSV on stdout: training
  # data for a classifier on embeddings. One row per document and topic.
  desc 'Export topic signals for a random sample of documents as CSV'
  task :export, [:sample] => :environment do |_task, args|
    documents = Document.complete.order('random()').limit((args[:sample] || 2000).to_i)

    puts CSV.generate_line(%w[document_id topic title body committee poi assigned])
    documents.each do |document|
      classifier = TopicClassifier.new(document)
      topics = classifier.topics
      classifier.signals.each do |key, found|
        puts CSV.generate_line([document.id, key, *found.values_at(:title, :body, :committee, :poi),
                                topics.include?(key)])
      end
    end
  end

  # --- gold set (see db/gold/README.md) ---------------------------------------

  desc 'Draw the gold sample into db/gold/topics.jsonl (refuses to replace one)'
  task :gold_sample, %i[random per_topic untagged] => :environment do |_task, args|
    options = { random: args[:random], per_topic: args[:per_topic], untagged: args[:untagged] }.compact.transform_values(&:to_i)
    set = TopicGoldSet.sample(**options)
    puts "#{set.entries.size} documents: #{set.entries.map(&:stratum).tally.map { |stratum, count| "#{count} #{stratum}" }.join(', ')}"
  end

  desc 'Write the unlabelled gold documents as markdown batches into tmp/gold'
  task :gold_texts, [:batch_size] => :environment do |_task, args|
    set = TopicGoldSet.load
    files = set.write_texts(Rails.root.join('tmp/gold'), batch_size: (args[:batch_size] || 25).to_i)
    puts "#{set.unlabelled.size} unlabelled, #{files.size} files in tmp/gold"
  end

  desc 'Import labels ("district/number: key, key" per line, "-" for none) into the gold set'
  task :gold_import, %i[file labeler] => :environment do |_task, args|
    set = TopicGoldSet.load
    count = set.import(File.readlines(args[:file] || abort('usage: rake "topics:gold_import[file,labeler]"')),
                       labeler: args[:labeler] || 'human')
    set.save
    puts "#{count} labels imported, #{set.labelled.size} of #{set.entries.size} labelled"
  end

  # Read-only. Pass verbose to list every wrong or missing tag.
  desc 'Measure the rules against the gold set: precision and recall per topic'
  task :evaluate, [:verbose] => :environment do |_task, args|
    evaluation = TopicEvaluation.new.run
    percent = ->(value) { value ? format('%5.1f%%', 100 * value) : '    –' }

    puts "#{evaluation.evaluated} labelled documents evaluated" \
         "#{", #{evaluation.missing} not in this database" if evaluation.missing.positive?}\n\n"
    puts 'precision  recall  recall (random)   tp   fp   fn  topic'
    rows = evaluation.scores.map { |key, score| [Topic.find(key).label, score] } + [['all topics', evaluation.total]]
    rows.each do |label, score|
      puts format('%<p>9s %<r>7s %<rr>16s %<tp>4d %<fp>4d %<fn>4d  %<label>s', p: percent[score.precision], r: percent[score.recall],
                                                                               rr: percent[score.random_recall], tp: score.tp,
                                                                               fp: score.fp, fn: score.fn, label:)
    end
    puts "\nRandom documents with a topic that the rules tag with nothing: #{evaluation.random_untagged}"

    next unless args[:verbose]

    evaluation.misses.group_by(&:topic).each do |topic, misses|
      puts "\n#{topic.label}"
      misses.sort_by(&:kind).each do |miss|
        sign = miss.kind == :false_positive ? '+' : '-'
        puts "  #{sign} #{miss.entry.key.ljust(28)} #{miss.document.title.to_s.squish.truncate(110)}"
      end
    end
  end
end
