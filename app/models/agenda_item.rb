class AgendaItem < ApplicationRecord

  belongs_to :meeting
  belongs_to :document, optional: true

  validates :meeting, presence: true
end
