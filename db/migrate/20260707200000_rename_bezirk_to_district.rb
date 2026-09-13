# frozen_string_literal: true

# Bezirk is District everywhere else in this codebase, so the geo columns should
# say so too. A separate migration rather than an edit to the earlier ones,
# because streets.bezirke predates this branch and may already be deployed.
class RenameBezirkToDistrict < ActiveRecord::Migration[8.1]
  def change
    rename_column :streets, :bezirke, :district_numbers
    rename_column :quarters, :bezirk, :district_number
    rename_column :quarters, :bezirk_name, :district_name
  end
end
