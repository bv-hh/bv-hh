# frozen_string_literal: true

require 'test_helper'

class TopicGoldSetTest < ActiveSupport::TestCase
  setup do
    @dir = Pathname(Dir.mktmpdir)
    @path = @dir.join('topics.jsonl')
    Document.update_all(topics: [])
    documents(:document_7).update_columns(topics: %w[strassenverkehr]) # rubocop:disable Rails/SkipsModelValidations
  end

  teardown { FileUtils.rm_rf(@dir) }

  test 'sample draws each stratum once per document and saves the set' do
    set = TopicGoldSet.sample(random: 3, per_topic: 1, untagged: 20, path: @path)

    keys = set.entries.map(&:key)
    assert_equal keys.uniq, keys
    assert_equal(3, set.entries.count { |entry| entry.stratum == 'random' })
    assert_includes keys, 'hamburg-nord/21-4776', 'the only document tagged with a topic'
    assert(set.entries.all? { |entry| entry.topics.nil? })
    assert_equal set.entries.map(&:to_h), TopicGoldSet.load(@path).entries.map(&:to_h)
  end

  test 'sample refuses to replace an existing set' do
    File.write(@path, '')

    assert_raises(ArgumentError) { TopicGoldSet.sample(path: @path) }
  end

  test 'import checks every line and never replaces a human label' do
    set = gold_set(%w[21-4776 21-4512])
    set.entries.last.topics = ['kultur']
    set.entries.last.labeler = 'human'

    count = set.import(["hamburg-nord/21-4776: strassenverkehr, radverkehr\n", "hamburg-nord/21-4512: -\n", "# comment\n"],
                       labeler: 'claude')

    assert_equal 1, count
    assert_equal [%w[radverkehr strassenverkehr], %w[kultur]], set.entries.map(&:topics)
    assert_equal %w[claude human], set.entries.map(&:labeler)
  end

  test 'import rejects unknown documents and topics before changing anything' do
    set = gold_set(%w[21-4776])

    assert_raises(ArgumentError) { set.import(['hamburg-nord/21-4776: gibtsnicht'], labeler: 'claude') }
    assert_raises(ArgumentError) { set.import(['hamburg-nord/0-0: -'], labeler: 'claude') }
    assert_nil set.entries.first.topics
  end

  test 'texts hold the unlabelled documents without their rule topics' do
    set = gold_set(%w[21-4776 21-4512])
    set.entries.last.topics = []
    set.entries.last.labeler = 'human'

    files = set.write_texts(@dir.join('texts'), batch_size: 10)

    text = File.read(files.first)
    assert_equal 1, files.size
    assert_includes text, '## hamburg-nord/21-4776'
    assert_includes text, documents(:document_7).title
    assert_not_includes text, '21-4512'
    assert_not_includes text, 'strassenverkehr'
  end

  private

  def gold_set(numbers)
    entries = numbers.map do |number|
      TopicGoldSet::Entry.new(district: 'hamburg-nord', number:, stratum: 'random', topics: nil, labeler: nil)
    end
    TopicGoldSet.new(entries, @path)
  end
end
