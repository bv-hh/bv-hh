class GoogleMaps

  FIND_PLACE = "https://maps.googleapis.com/maps/api/place/findplacefromtext"

  class << self
    def find_place(query, options = {})
      options = options.merge({
        input: query,
        inputtype: 'textquery',
        fields: [:place_id, :name, :type, :formatted_address, :geometry].join(','),
        language: :de,
        locationbias: 'rectangle:53.556154,9.9588098|53.68192209999999,10.089918',
        key: Rails.application.credentials.google_maps_api_key
      })

      url = URI.parse("#{FIND_PLACE}/json#{query_string(options)}").to_s

      result = response(url)

      result&.is_a?(Hash) && result&.try(:[], 'status') == 'OK' ? result : nil
    end

    def query_string(options)
      '?' + URI.encode_www_form(options) unless options.empty?
    end

    def response(url)
      begin
        result = JSON.parse(HTTPClient.new.get_content(url))
      rescue StandardErrror => e
        Rails.logger.error e.message.to_s
        raise e
      end

      result
    end
  end
end
