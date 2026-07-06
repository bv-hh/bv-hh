# frozen_string_literal: true

class DropLegacyMemberTables < ActiveRecord::Migration[8.0]
  # These tables leaked into schema.rb from an abandoned branch that was never
  # merged to main (no migrations, no models reference them). Drop them so the
  # new members/memberships schema can be created cleanly.
  def up
    drop_table :committee_members, if_exists: true
    drop_table :members, if_exists: true
    drop_table :groups, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
