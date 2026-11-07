# frozen_string_literal: true

require 'test_helper'

class PopulationTest < ActiveSupport::TestCase
  test 'a Stadtteil of its own has its own figure' do
    assert_equal [['Ohlsdorf'], Population::RESIDENTS['Ohlsdorf']], Population.area('Ohlsdorf')
  end

  test 'two Stadtteile counted together share one figure' do
    expected = [%w[Waltershof Finkenwerder], Population::RESIDENTS['Waltershof und Finkenwerder']]

    assert_equal expected, Population.area('Finkenwerder')
    assert_equal expected, Population.area('Waltershof')
  end

  test 'no figure for Neuwerk, nor for a name it does not know' do
    assert_nil Population.area('Neuwerk')
    assert_nil Population.area('Atlantis')
  end

  test 'every combined entry has its figure' do
    assert_empty Population::AREAS.keys - Population::RESIDENTS.keys
  end

  # 104 Stadtteile: 95 with a figure of their own, eight in four pairs, and
  # Neuwerk.
  test 'covers every Stadtteil but Neuwerk' do
    assert_equal 99, Population::RESIDENTS.size
    assert_equal 103, Population::RESIDENTS.size - Population::AREAS.size + Population::AREAS.values.flatten.size
  end
end
