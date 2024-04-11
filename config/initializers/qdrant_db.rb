class QdrantDb
  attr_reader :connection

  def initialize
    llm = Langchain::LLM::OpenAI.new(api_key: ENV["OPENAI_API_KEY"])

    @connection = Langchain::Vectorsearch::Qdrant.new(
      url: ENV['QDRANT_URL'],
      api_key: ENV['QDRANT_API_KEY'],
      index_name: 'bezirkr',
      llm: llm
    )
  end

end