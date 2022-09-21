# frozen_string_literal: true

class Group < ApplicationRecord

  belongs_to :district

  has_many :members, dependent: :nullify

  validates :name, presence: true
end
