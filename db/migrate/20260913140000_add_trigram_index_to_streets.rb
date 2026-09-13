# frozen_string_literal: true

# Backs Street.fuzzy_for. Documents reach us as OCR'd PDFs, so street names
# arrive damaged ("Langenhomer Chaussee" for Langenhorner, "Hudtwalkerstraße"
# for Hudtwalckerstraße) or in a spelling the register does not use. Correcting
# those was the one thing Google Places did that the exact-match registers
# cannot, and a trigram index answers it locally — and better, because the
# lookup can be constrained to the district.
class AddTrigramIndexToStreets < ActiveRecord::Migration[8.1]
  def change
    add_index :streets, :normalized_name, using: :gin, opclass: :gin_trgm_ops,
                                          name: 'index_streets_on_normalized_name_trgm'
  end
end
