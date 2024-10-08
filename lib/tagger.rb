class Tagger
  TAGGER_HOST = 'http://localhost:8080'
  TAGGER_PATH = '/api/v1/tagger'

  def self.tag(text)
    connection = Faraday.new(TAGGER_HOST)
    data = { text: text }.to_json
    response = connection.post(TAGGER_PATH, data, content_type: 'application/json')

    raise 'Error requesting tagger' unless response.success?

    JSON.parse(response.body)
  end
end
