class District < ApplicationRecord

  has_many :documents

  validates :name, presence: true
  validates :allris_base_url, presence: true

  scope :by_name, -> { order(:name) }

  def to_param
    name.parameterize
  end

  def self.lookup(path)
    @districts ||= District.all.inject({}) {|l, d| l[d.name.parameterize] = d; l }

    @districts[path.parameterize]
  end

end
