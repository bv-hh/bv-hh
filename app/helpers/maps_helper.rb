# frozen_string_literal: true

module MapsHelper

  def marker_popup(location, documents)
    render partial: 'maps/marker_popup', locals: { location: location, documents: documents }
  end
end
