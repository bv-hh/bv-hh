# frozen_string_literal: true

require 'test_helper'

class AttendanceExtractorTest < ActiveSupport::TestCase
  test 'parses committee attendance including substitutes and excludes administration' do
    entries = AttendanceExtractor.new(file_fixture('niederschrift_committee.txt').read).entries

    assert_equal 19, entries.size
    surnames = entries.map(&:surname)

    # voting and non-voting members are included
    assert_includes surnames, 'Artus'
    assert_includes surnames, 'Bläsing'
    # administrative attendees are ignored
    assert_not_includes surnames, 'Engelbrecht' # Verwaltung
    assert_not_includes surnames, 'Hannig'      # Protokollführung

    # stand-ins are flagged
    substitutes = entries.select(&:substitute).map(&:surname)
    assert_equal %w[Grichisch Leßner Baumann].sort, substitutes.sort

    grichisch = entries.find { |e| e.surname == 'Grichisch' }
    assert_equal 'GRÜNE', grichisch.party
    assert grichisch.present
  end

  test 'handles Hamburg-Mitte party sub-headers and "Vertretung für" substitutes' do
    entries = AttendanceExtractor.new(file_fixture('niederschrift_mitte.txt').read).entries

    # party is a sub-header line, not a column, yet gets attached to each member
    assert_operator entries.count(&:party), :>=, entries.size - 1
    linke = entries.find { |e| e.surname == 'Hercher-Reis' }
    assert_equal 'LINKE', linke.party
    assert linke.substitute # "Vertretung für: Frau Jürgens, Hildegard"
  end

  test 'handles Altona indented rows and Ständige Vertretung substitutes' do
    entries = AttendanceExtractor.new(file_fixture('niederschrift_altona.txt').read).entries

    # rows are indented by a space in this district; they must still be detected
    assert_includes entries.map(&:surname), 'Wolpert'
    assert(entries.select(&:substitute).all? { |e| e.role == 'Ständige Vertretung' })
    assert_operator entries.count(&:substitute), :>=, 1
  end

  test 'parses plenum attendance with all members present' do
    entries = AttendanceExtractor.new(file_fixture('niederschrift_plenum.txt').read).entries

    assert_equal 47, entries.size
    assert(entries.all?(&:present))
    assert_not(entries.any?(&:substitute))
    assert_equal 'Vorsitzendes Mitglied', entries.first.role
  end
end
