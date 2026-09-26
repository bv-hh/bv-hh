# frozen_string_literal: true

# Keeps the page a record was last parsed from (see AllrisPage).
module WithAllrisPage
  extend ActiveSupport::Concern

  included do
    has_one :allris_page, as: :record, dependent: :destroy
  end

  def store_page(source)
    page = allris_page || build_allris_page
    page.update!(body: source, fetched_at: Time.current)
  end
end
