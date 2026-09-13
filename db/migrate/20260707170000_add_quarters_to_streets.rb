# frozen_string_literal: true

# A street that crosses several Stadtteile carries one <dog:ortsteilname> per
# segment in the register, but the importer only kept the first one. Store all
# of them so "which Stadtteile does this street touch" can be answered without
# any geometry.
#
# Also renames the existing singular column to English, so the whole gazetteer
# speaks one language: Bezirk stays `district`, Stadtteil becomes `quarter`.
class AddQuartersToStreets < ActiveRecord::Migration[8.1]
  def change
    rename_column :streets, :stadtteil, :quarter

    change_table :streets, bulk: true do |t|
      # Every Stadtteil the street runs through, not just the one holding its
      # representative point. `quarter` stays as that representative name, used
      # for display and formatted_address.
      t.string :quarters, array: true, null: false, default: []
      # The official Ortsteil keys behind those names, e.g. "0401".
      t.string :quarter_keys, array: true, null: false, default: []
    end

    add_index :streets, :quarters, using: :gin
    add_index :streets, :quarter_keys, using: :gin

    up_only do
      execute <<~SQL.squish
        UPDATE streets
        SET quarters = ARRAY[quarter]
        WHERE quarter IS NOT NULL AND quarter <> ''
      SQL
    end
  end
end
