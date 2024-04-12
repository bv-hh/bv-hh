class QdrantDb
  attr_reader :connection

  def initialize
    llm = Langchain::LLM::OpenAI.new(api_key: Rails.application.credentials.openai_api_key)

    @connection = Langchain::Vectorsearch::Qdrant.new(
      url: 'http://qdrant:6333',
      api_key: ENV['QDRANT_API_KEY'],
      index_name: 'bezirkr',
      llm: llm
    )
  end

end
