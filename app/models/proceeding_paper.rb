# == Schema Information
#
# Table name: proceeding_papers
#
#  id            :integer          not null, primary key
#  proceeding_id :integer          not null
#  parldok_id    :integer          not null
#  period        :integer          not null
#  number        :integer          not null
#  kind          :string           not null
#  title         :string           not null
#  date          :date
#  full_text     :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_proceeding_papers_on_parldok_id         (parldok_id) UNIQUE
#  index_proceeding_papers_on_period_and_number  (period,number) UNIQUE
#  index_proceeding_papers_on_proceeding_id      (proceeding_id)
#

# frozen_string_literal: true

# One Drucksache of the Bürgerschaft, part of a Proceeding. Unique by period and
# number, which is how district Drucksachen cite it ("Drucksache 23/5356").
class ProceedingPaper < ApplicationRecord
  belongs_to :proceeding

  validates :parldok_id, :period, :number, :kind, :title, presence: true

  scope :without_text, -> { where(full_text: nil) }

  def designation
    "#{period}/#{number}"
  end

  def parldok_url
    ParldokClient.document_url(parldok_id)
  end
end
