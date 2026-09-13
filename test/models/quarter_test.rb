# frozen_string_literal: true

# == Schema Information
#
# Table name: quarters
#
#  id          :integer          not null, primary key
#  name        :string           not null
#  slug        :string           not null
#  key         :string           not null
#  number      :string
#  bezirk      :integer
#  bezirk_name :string
#  geometry    :jsonb            not null
#  min_lat     :float
#  max_lat     :float
#  min_lng     :float
#  max_lng     :float
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_quarters_on_bezirk  (bezirk)
#  index_quarters_on_key     (key) UNIQUE
#  index_quarters_on_name    (name)
#  index_quarters_on_slug    (slug) UNIQUE
#

require 'test_helper'

class QuarterTest < ActiveSupport::TestCase
  setup do
    Quarter.reset!
  end

  teardown do
    Quarter.reset!
  end

  test 'contains? is true for a point inside the polygon' do
    assert_predicate quarters(:barmbek_nord), :present?
    assert quarters(:barmbek_nord).contains?(53.5891, 10.0028)
  end

  test 'contains? is false for a point outside the polygon' do
    assert_not quarters(:barmbek_nord).contains?(53.70, 10.05)
  end

  test 'contains? is false for a point inside a hole' do
    duvenstedt = quarters(:duvenstedt)

    assert duvenstedt.contains?(53.70, 10.05), 'precondition: point is inside the exterior ring'
    assert_not duvenstedt.contains?(53.725, 10.03), 'point sits in the carved-out inner ring'
  end

  test 'contains? rejects a point outside the bounding box without walking the rings' do
    assert_not quarters(:barmbek_nord).contains?(52.5, 13.4)
  end

  test 'covering returns every Quarter holding the point' do
    assert_equal ['Barmbek-Nord'], Quarter.covering(53.5891, 10.0028)
    assert_equal ['Lokstedt'], Quarter.covering(53.58, 9.75)
  end

  test 'covering returns nothing for a point outside Hamburg' do
    assert_empty Quarter.covering(52.5, 13.4)
  end

  test 'covering returns nothing when coordinates are missing' do
    assert_empty Quarter.covering(nil, nil)
    assert_empty Quarter.covering(53.5891, nil)
  end

  test 'lookup finds a Quarter by its slug' do
    assert_equal 'Groß Borstel', Quarter.lookup('gross-borstel').name
  end

  test 'lookup parameterizes the given path and tolerates the plain name' do
    assert_equal 'Groß Borstel', Quarter.lookup('Groß Borstel').name
  end

  test 'lookup returns nil for an unknown or blank slug' do
    assert_nil Quarter.lookup('gibtsnicht')
    assert_nil Quarter.lookup('')
    assert_nil Quarter.lookup(nil)
  end

  test 'slug round-trips through to_param' do
    Quarter.find_each do |quarter|
      assert_equal quarter, Quarter.lookup(quarter.to_param)
    end
  end

  test 'canonical_names maps user input to the register spelling' do
    assert_equal %w[Lokstedt Duvenstedt], Quarter.canonical_names(['lokstedt', '  DUVENSTEDT '])
  end

  test 'canonical_names drops unknown names and deduplicates' do
    assert_equal ['Lokstedt'], Quarter.canonical_names(%w[Lokstedt lokstedt gibtsnicht])
    assert_empty Quarter.canonical_names([])
    assert_empty Quarter.canonical_names(nil)
  end

  test 'district resolves the Bezirk number to a District' do
    assert_equal 'Hamburg-Nord', quarters(:barmbek_nord).district.name
  end

  # Only Hamburg-Nord exists in districts.yml, so Lokstedt (Bezirk 3) stands in
  # for a Quarter whose Bezirk has not been onboarded yet.
  test 'district is nil when no District exists for the Bezirk number' do
    assert_nil quarters(:lokstedt).district
  end
end
