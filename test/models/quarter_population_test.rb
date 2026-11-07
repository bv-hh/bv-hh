# frozen_string_literal: true

require 'test_helper'

class QuarterPopulationTest < ActiveSupport::TestCase
  test 'a Stadtteil of its own has its own figure' do
    assert_equal [['Ohlsdorf'], QuarterPopulation::RESIDENTS['Ohlsdorf']], QuarterPopulation.area('Ohlsdorf')
  end

  test 'two Stadtteile counted together share one figure' do
    expected = [%w[Waltershof Finkenwerder], QuarterPopulation::RESIDENTS['Waltershof und Finkenwerder']]

    assert_equal expected, QuarterPopulation.area('Finkenwerder')
    assert_equal expected, QuarterPopulation.area('Waltershof')
  end

  test 'no figure for Neuwerk, nor for a name it does not know' do
    assert_nil QuarterPopulation.area('Neuwerk')
    assert_nil QuarterPopulation.area('Atlantis')
  end

  test 'every combined entry has its figure' do
    assert_empty QuarterPopulation::AREAS.keys - QuarterPopulation::RESIDENTS.keys
  end

  # 104 Stadtteile: 95 with a figure of their own, eight in four pairs, and
  # Neuwerk.
  test 'covers every Stadtteil but Neuwerk' do
    assert_equal 99, QuarterPopulation::RESIDENTS.size
    assert_equal 103, QuarterPopulation::RESIDENTS.size - QuarterPopulation::AREAS.size + QuarterPopulation::AREAS.values.flatten.size
  end
end
