# frozen_string_literal: true

class MapsController < ApplicationController
  HH_CENTER = { lat: 53.5488282, lng: 9.98717029 }

  def show
    if @district.present?
      @center = @district.center
      @zoom = 12
    else
      @center = HH_CENTER
      @zoom = 11
    end
  end

  def markers
    months = params[:months].presence&.to_i || 3
    locations = DocumentLocation.joins(:document)
    locations = locations.merge(Document.where(district: @district)) if @district.present?
    locations = locations.merge(Document.in_last_months(months))
    markers = locations.group_by(&:location).map do |location, documents|
      {
        position: [location.latitude, location.longitude],
        name: location.name,
        address: location.formatted_address,
        documents: documents.map do |document_location|
          document = document_location.document
          {
            number: document.number,
            title: document.title,
            path: document_path(document),
          }
        end,
      }
    end

    render json: markers
  end
end
