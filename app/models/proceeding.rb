# == Schema Information
#
# Table name: proceedings
#
#  id                 :integer          not null, primary key
#  parldok_process_id :integer
#  period             :integer          not null
#  number             :integer          not null
#  title              :string           not null
#  abstract           :text
#  state              :string
#  steps              :jsonb            not null
#  date               :date
#  full_text          :text
#  checked_at         :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_proceedings_on_date                (date)
#  index_proceedings_on_parldok_process_id  (parldok_process_id) UNIQUE
#

# frozen_string_literal: true

# A matter before the Hamburgische Bürgerschaft, as ParlDok tracks it: a
# Vorgang (an Antrag, the Ausschussbericht on it, how it was decided), or a
# single Drucksache that opens none, such as a Schriftliche Kleine Anfrage,
# whose PDF holds the Senat's answer as well.
#
# Imported for what it says about places in the districts — "Verwandte Vorgänge
# in der Bürgerschaft" — not as a mirror of ParlDok, which stays the place to
# read the Bürgerschaft as a whole. Authors are not kept: the pages are about
# places, topics and decisions, not about who asked.
class Proceeding < ApplicationRecord
  has_many :papers, -> { order(:date, :number) }, class_name: 'ProceedingPaper', inverse_of: :proceeding,
                                                  dependent: :destroy

  validates :period, :number, :title, presence: true

  # As the Bürgerschaft cites it: "23/5356".
  def designation
    "#{period}/#{number}"
  end

  def parldok_url
    if parldok_process_id
      ParldokClient.vorgang_url(parldok_process_id)
    else
      papers.first&.parldok_url
    end
  end

  # The text of all its Drucksachen in order, for what reads the proceeding
  # as a whole. Reloads the papers: they get their text one at a time.
  def update_text!
    update!(full_text: papers.reload.filter_map(&:full_text).join("\n\n").presence)
  end
end
