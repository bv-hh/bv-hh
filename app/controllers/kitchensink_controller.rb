# frozen_string_literal: true

# Every chip and badge style from ChipHelper on one page, with real records, as
# the reference for new views. Routed outside production only.
class KitchensinkController < ApplicationController
  def show
    @noindex = true
    @title = 'Kitchensink'
    @locations = Location.where.not(formatted_address: nil).includes(:district).limit(3).to_a
    @quarters = Quarter.by_name.select(&:district).first(4)
    @topics = Topic.first(3)
    @districts = District.by_order.first(3)
  end
end
