# frozen_string_literal: true

class ExtractDocumentLocationsJob < ApplicationJob

  LIMIT = 100_000

  queue_as :documents

  def perform
    model = Mitie::NER.new(Rails.root.join('data', 'ner_model.dat').to_s)

    Document.locations_not_extracted.limit(LIMIT).find_each do |document|
      locations = model.doc(document.full_text).entities.filter_map do |entity|
        if entity[:tag] == 'LOCATION' && entity[:score] >= 0.5
          entity[:text].gsub(/[^0-9a-zöäüß\- ]/i, '')
        end
      end.uniq

      document.locations_extracted_at = Time.now
      document.extracted_locations = locations
      document.save!
    end
  end

end
