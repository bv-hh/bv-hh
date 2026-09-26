# frozen_string_literal: true

# The Parsing::VERSION a document was last parsed with. Existing rows stay NULL:
# they were parsed by the regex cleaner that deleted the spaces between words,
# and RefetchDocumentsJob fetches them again, oldest first.
class AddParserVersionToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :parser_version, :integer
    add_index :documents, %i[district_id parser_version updated_at]
  end
end
