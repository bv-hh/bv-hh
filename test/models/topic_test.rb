# frozen_string_literal: true

require 'test_helper'

class TopicTest < ActiveSupport::TestCase
  test 'loads every topic from config/topics.yml with a label and terms' do
    assert_operator Topic.count, :>, 1
    assert(Topic.all? { |topic| topic.label.present? && topic.title_tsquery.present? })
  end

  test 'keys are unique' do
    assert_equal Topic.keys.uniq, Topic.keys
  end

  test 'every tsquery is valid' do
    Topic.each do |topic|
      query = Document.connection.select_value(
        Document.sanitize_sql_array(["SELECT to_tsquery('german', ?)::text", topic.title_tsquery])
      )

      assert_predicate query, :present?, topic.key
    end
  end

  test 'no topic takes the Bezirksversammlung or the Hauptausschuss for a topical committee' do
    %w[Bezirksversammlung Hauptausschuss].each do |name|
      assert_empty Topic.select { |topic| topic.committee?(name) }, name
    end
  end

  test 'committee names match case-insensitively' do
    assert Topic.find(:radverkehr).committee?('Ausschuss für Verkehr und Mobilität')
    assert Topic.find('wohnen_bauen').committee?('Bauausschuss')
  end

  test 'find returns nil for an unknown key' do
    assert_nil Topic.find('unbekannt')
  end

  test 'slug dasherizes the key and serves as its param' do
    assert_equal 'kinder-jugend', Topic.find('kinder_jugend').slug
    assert_equal 'kinder-jugend', Topic.find('kinder_jugend').to_param
  end

  test 'lookup finds a topic by slug and by key' do
    assert_equal 'kinder_jugend', Topic.lookup('kinder-jugend').key
    assert_equal 'kinder_jugend', Topic.lookup('kinder_jugend').key
    assert_nil Topic.lookup('unbekannt')
  end

  test 'canonical_keys drops unknown values and returns keys in config order' do
    assert_equal %w[radverkehr kinder_jugend], Topic.canonical_keys(%w[kinder-jugend gibtsnicht radverkehr radverkehr])
  end

  test 'ranked orders by count, then label, and drops unknown keys' do
    ranked = Topic.ranked('kultur' => 2, 'radverkehr' => 2, 'gruen' => 5, 'unbekannt' => 9)
                  .map { |topic, count| [topic.key, count] }

    assert_equal [['gruen', 5], ['kultur', 2], ['radverkehr', 2]], ranked
  end
end
