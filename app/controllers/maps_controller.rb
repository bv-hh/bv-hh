# frozen_string_literal: true

class MapsController < ApplicationController

  HH_CENTER = { lat: 53.5488282, lng: 9.98717029 }

  def show
    if @district.present?
      @center = @district.center
    else
      @center = HH_CENTER
    end
  end

  def markers
  end
end
