# frozen_string_literal: true

class GoogleMaps
  FIND_PLACE = 'https://maps.googleapis.com/maps/api/place/findplacefromtext'

  class << self
    def find_places(query, district, options = {})
      result = district.places.find_by(query: query)
      if result.present?
        Rails.logger.info "GoogleMaps: Found cached locations for query: #{query}"
        return result.locations
      end

      result = find_places_uncached(query, district, options)
      if result.is_a?(Hash) && result&.try(:[], 'status') == 'OK'
        Rails.logger.info "GoogleMaps: Found #{result['candidates'].size} locations for query: #{query}"
        district.places.create!(query: query, locations: result)
        result
      end
    end

    def find_places_uncached(query, district, options = {})
      nw = district.bounds.first.join(',')
      se = district.bounds.last.join(',')
      bias = "rectangle:#{nw}|#{se}"
      options = options.merge({
                                input: query,
                                inputtype: 'textquery',
                                fields: %i[place_id name type formatted_address geometry].join(','),
                                language: :de,
                                locationbias: bias,
                                key: Rails.application.credentials.google_maps_api_key,
                              })

      url = URI.parse("#{FIND_PLACE}/json#{query_string(options)}").to_s

      response(url)
    end

    def query_string(options)
      "?#{URI.encode_www_form(options)}" unless options.empty?
    end

    def response(url)
      begin
        result = JSON.parse(HTTPClient.new.get_content(url))
      rescue StandardError => e
        Rails.logger.error e.message.to_s
        raise e
      end

      result
    end
  end
end
