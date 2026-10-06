# frozen_string_literal: true

# One of the topics a Drucksache can be tagged with, read from
# config/topics.yml. Documents store the keys in documents.topics; which ones
# apply is decided by TopicClassifier.
class Topic
  # Stored in documents.topics_version. Bump it whenever config/topics.yml or
  # TopicClassifier change what a document would be tagged with, then run
  # `rake topics:reassign_later` (or `rake topics:reassign`, which enqueues
  # from the rake process and waits).
  VERSION = 6

  CONFIG = Rails.root.join('config/topics.yml')

  attr_reader :key, :label, :description, :terms, :title_terms, :committees, :poi_categories, :yields_to,
              :yields_unless

  class << self
    include Enumerable

    def all
      @all ||= YAML.load_file(CONFIG).map { |key, attributes| new(key, **attributes.symbolize_keys) }.freeze
    end

    def each(&)
      all.each(&)
    end

    def keys
      map(&:key)
    end

    def find(key)
      all.find { |topic| topic.key == key.to_s }
    end

    # By URL slug, and by key too, so /themen/kinder_jugend still resolves and
    # can be redirected to its canonical /themen/kinder-jugend.
    def lookup(value)
      value = value.to_s
      all.find { |topic| topic.slug == value || topic.key == value }
    end

    # [Topic, count] pairs from Document.topic_counts, most frequent first.
    # Keys no longer in the config are dropped.
    def ranked(counts)
      counts.filter_map { |key, count| (topic = find(key)) && [topic, count] }
            .sort_by { |topic, count| [-count, topic.label] }
    end

    # Keys only, unknown ones dropped, in config order: whatever reaches SQL is
    # a key the corpus can actually hold.
    def canonical_keys(values)
      wanted = Array(values).filter_map { |value| lookup(value)&.key }
      keys & wanted
    end
  end

  def initialize(key, label:, description: nil, terms: [], title_terms: [], committees: [], poi_categories: [],
    yields_to: [], yields_unless: [])
    @key = key.to_s
    @label = label
    @description = description
    @terms = terms
    @title_terms = title_terms
    @committees = committees.map { |pattern| Regexp.new(pattern, Regexp::IGNORECASE) }
    @poi_categories = poi_categories
    @yields_to = yields_to
    @yields_unless = yields_unless
  end

  def slug
    key.dasherize
  end

  def to_param
    slug
  end

  # to_tsquery input for the title, or nil when the topic has no terms for it.
  def title_tsquery
    (terms + title_terms).join(' | ').presence
  end

  # to_tsquery input for the full text, or nil.
  def body_tsquery
    terms.join(' | ').presence
  end

  # to_tsquery input for the title terms that keep this topic although it
  # would yield to another, or nil.
  def yields_unless_tsquery
    yields_unless.join(' | ').presence
  end

  def committee?(name)
    committees.any? { |pattern| pattern.match?(name.to_s) }
  end

  def to_s
    label
  end
end
