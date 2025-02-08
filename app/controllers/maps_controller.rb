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

    documents_query = Document.in_last_months(months)
    documents_query = documents_query.where(district: @district) if @district.present?

    locations = DocumentLocation.joins(:document).includes(:location, :document)
    locations = locations.merge(documents_query)

    markers = locations.distinct.group_by(&:location).map do |location, documents|
      {
        position: [location.latitude, location.longitude],
        path: location_path(location),
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
