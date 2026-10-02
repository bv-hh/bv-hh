# frozen_string_literal: true

# An area of a district and the committees responsible for it: a
# Regionalausschuss, or a committee that acts as one under another name
# (Cityausschuss, Kerngebietsausschuss). Read from config/area_committees.yml,
# which explains where the table comes from.
#
# Committee#local? is a different, older notion (the name contains
# "Regionalausschuss") that the topic and location extraction use.
class AreaCommittee
  CONFIG = Rails.root.join('config/area_committees.yml')

  attr_reader :district_name, :committee_names, :quarters

  class << self
    def all
      @all ||= YAML.load_file(CONFIG).flat_map do |district_name, areas|
        areas.map { |area| new(district_name, committee_names: area['committees'], quarters: area['quarters']) }
      end.freeze
    end

    # The committees responsible for any of the Stadtteile (by register name).
    def committees_for(quarter_names)
      areas = all.select { |area| area.quarters.intersect?(quarter_names) }
      Committee.where(id: areas.flat_map { |area| area.committees.ids })
    end
  end

  def initialize(district_name, committee_names:, quarters:)
    @district_name = district_name
    @committee_names = committee_names.freeze
    @quarters = quarters.freeze
  end

  def committees
    Committee.joins(:district).where(districts: { name: district_name }, name: committee_names)
  end
end
