# frozen_string_literal: true

require 'test_helper'

class AreaCommitteeTest < ActiveSupport::TestCase
  test 'every Stadtteil belongs to at most one area' do
    quarters = AreaCommittee.all.flat_map(&:quarters)

    assert_empty quarters.tally.select { |_name, count| count > 1 }.keys
  end

  test 'every area names its district, committees and Stadtteile' do
    districts = %w[Hamburg-Mitte Eimsbüttel Hamburg-Nord Wandsbek Bergedorf Harburg]
    areas = AreaCommittee.all

    areas.each do |area|
      assert_includes districts, area.district_name
      assert_predicate area.committee_names, :any?
      assert_predicate area.quarters, :any?
    end
  end

  test 'finds the committees of a Stadtteil in its district only' do
    ohlsdorf = districts(:hamburg_nord).committees.create!(name: 'Regionalausschuss Langenhorn-Fuhlsbüttel-Ohlsdorf-Alsterdorf-Groß Borstel')
    District.create!(name: 'Altona', order: 2, allris_base_url: 'https://example.test')
            .committees.create!(name: ohlsdorf.name)

    assert_equal [ohlsdorf], AreaCommittee.committees_for(['Ohlsdorf']).to_a
    assert_equal [committees(:rega_ewi)], AreaCommittee.committees_for(%w[Winterhude]).to_a
    assert_empty AreaCommittee.committees_for(%w[Ottensen])
  end
end
