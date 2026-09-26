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
end
