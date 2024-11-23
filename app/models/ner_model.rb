# frozen_string_literal: true

class NerModel
  def self.model
    @model ||= Mitie::NER.new(Rails.root.join('data/ner_model.dat').to_s)
  end
end
