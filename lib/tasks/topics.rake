# frozen_string_literal: true

require 'csv'

namespace :topics do
  # After a bump of Topic::VERSION, and once for the initial backfill. New and
  # reparsed documents get their topics through AssignDocumentLocationsJob.
  desc 'Enqueue topic assignment for documents classified by an older Topic::VERSION'
  task :reassign, [:district] => :environment do |_task, args|
    district = District.find_by!(name: args[:district]) if args[:district]
    puts "Enqueued #{ReassignDocumentTopicsJob.perform_now(district)} documents"
  end

  # The same, but the enqueueing runs in the worker: returns at once, for a
  # deploy that should not wait for tens of thousands of inserts.
  desc 'Start the topic reassignment in the worker and return immediately'
  task :reassign_later, [:district] => :environment do |_task, args|
    district = District.find_by!(name: args[:district]) if args[:district]
    ReassignDocumentTopicsJob.perform_later(district)
    puts "ReassignDocumentTopicsJob enqueued#{" for #{district.name}" if district}"
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

  # Trains a classifier per topic on the embeddings (TopicTrainer) and applies
  # it to the corpus. Run after the embeddings are complete, and again after a
  # rule change, since the rules are its teacher.
  desc 'Train the topic classifier on the embeddings and reclassify the corpus'
  task train: :environment do
    percent = ->(value) { value ? format('%5.1f%%', 100 * value) : '    –' }

    puts 'precision  recall  positives  topic      (validation, against the rules)'
    TopicTrainer.new.train!.each do |result|
      metrics = result.metrics.symbolize_keys
      puts format('%<p>9s %<r>7s %<n>10d  %<label>s', p: percent[metrics[:precision]], r: percent[metrics[:recall]],
                                                      n: metrics[:positives], label: Topic.find(result.topic).label)
    end
    Rake::Task['topics:classify'].invoke
  end

  desc 'Apply the trained topic classifier to every embedded document'
  task classify: :environment do
    puts "#{TopicModel.classify_all!} documents changed"
  end

  # --- gold set (see db/gold/README.md) ---------------------------------------
  #
  # Every gold task works on the tuning set unless GOLD_SET=test is given.

  gold_set = -> { ENV.fetch('GOLD_SET', 'tuning') }
  gold_texts_dir = -> { Rails.root.join('tmp/gold', gold_set.call) }

  # The test and calibration sets are random documents only, none of them in
  # another set.
  desc 'Draw a gold sample (refuses to replace one; GOLD_SET=test or calibration for the random-only sets)'
  task :gold_sample, %i[random per_topic untagged] => :environment do |_task, args|
    options = { random: args[:random], per_topic: args[:per_topic], untagged: args[:untagged] }.compact.transform_values(&:to_i)
    unless gold_set.call == 'tuning'
      others = (TopicGoldSet::SETS.keys - [gold_set.call]).flat_map { |name| TopicGoldSet.load(TopicGoldSet.path_for(name)).entries }
      options = { per_topic: 0, untagged: 0, exclude: others.map(&:key) }.merge(options)
    end
    set = TopicGoldSet.sample(path: TopicGoldSet.path_for(gold_set.call), **options)
    puts "#{set.entries.size} documents: #{set.entries.map(&:stratum).tally.map { |stratum, count| "#{count} #{stratum}" }.join(', ')}"
  end

  # The classifier's additions per topic, into the calibration set: a random
  # sample holds too few of a rare topic's. Needs trained topic models.
  desc 'Add documents each topic classifier adds to the rules to the calibration set (optionally for one topic)'
  task :gold_sample_additions, %i[per_topic topic] => :environment do |_task, args|
    set = TopicGoldSet.load(TopicGoldSet::CALIBRATION_PATH)
    others = (TopicGoldSet::SETS.keys - ['calibration']).flat_map { |name| TopicGoldSet.load(TopicGoldSet.path_for(name)).entries }
    before = set.entries.size
    topic = args[:topic] && (Topic.find(args[:topic]) || abort("unknown topic #{args[:topic]}"))
    set.draw_additions(per_topic: (args[:per_topic] || 15).to_i, exclude: others.map(&:key), topics: topic&.key)
    set.save
    puts "#{set.entries.size - before} documents added: " \
         "#{set.entries.drop(before).map(&:stratum).tally.map { |stratum, count| "#{count} #{stratum}" }.join(', ')}"
  end

  desc 'Write the unlabelled gold documents as markdown batches into tmp/gold/<set>'
  task :gold_texts, [:batch_size] => :environment do |_task, args|
    set = TopicGoldSet.load(TopicGoldSet.path_for(gold_set.call))
    files = set.write_texts(gold_texts_dir.call, batch_size: (args[:batch_size] || 25).to_i)
    puts "#{set.unlabelled.size} unlabelled, #{files.size} files in #{gold_texts_dir.call}"
  end

  desc 'Import labels ("district/number: key, key" per line, "-" for none) into the gold set'
  task :gold_import, %i[file labeler] => :environment do |_task, args|
    set = TopicGoldSet.load(TopicGoldSet.path_for(gold_set.call))
    count = set.import(File.readlines(args[:file] || abort('usage: rake "topics:gold_import[file,labeler]"')),
                       labeler: args[:labeler] || 'human')
    set.save
    puts "#{count} labels imported, #{set.labelled.size} of #{set.entries.size} labelled"
  end

  # Read-only. Pass verbose to list every wrong or missing tag. With trained
  # topic models, rules + classifier are measured next to the rules alone, and
  # the misses listed are those of the combination.
  desc 'Measure the rules (and the classifier) against the gold set: precision and recall per topic'
  task :evaluate, [:verbose] => :environment do |_task, args|
    set = TopicGoldSet.load(TopicGoldSet.path_for(gold_set.call))
    rules = TopicEvaluation.new(set).run
    combined = TopicEvaluation.new(set, tagger: TopicEvaluation::COMBINED).run if TopicModel.current.exists?
    evaluation = combined || rules
    percent = ->(value) { value ? format('%5.1f%%', 100 * value) : '    –' }
    counts = ->(score) { format('%<tp>4d %<fp>4d %<fn>4d', tp: score.tp, fp: score.fp, fn: score.fn) }
    rates = lambda do |score|
      format('%<p>9s %<r>7s %<rr>16s', p: percent[score.precision], r: percent[score.recall], rr: percent[score.random_recall])
    end

    puts "#{gold_set.call} set: #{evaluation.evaluated} labelled documents evaluated" \
         "#{", #{evaluation.missing} not in this database" if evaluation.missing.positive?}\n\n"
    puts 'precision  recall  recall (random)   tp   fp   fn' \
         "#{'  | rules + classifier: precision  recall  recall (random)   tp   fp   fn' if combined}  topic"

    rows = Topic.keys.map { |key| [Topic.find(key).label, rules.scores[key], combined&.scores&.dig(key)] }
    rows << ['all topics', rules.total, combined&.total]
    rows.each do |label, score, combined_score|
      columns = [rates[score], counts[score]]
      columns += ['  |              ', rates[combined_score], counts[combined_score]] if combined_score
      puts "#{columns.join(' ')}  #{label}"
    end
    puts "\nRandom documents with a topic that the rules tag with nothing: #{rules.random_untagged}"
    puts "... that rules + classifier tag with nothing: #{combined.random_untagged}" if combined

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
