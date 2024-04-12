class QdrantDb
  attr_reader :connection

  def initialize
    llm = Langchain::LLM::OpenAI.new(
      api_key: Rails.application.credentials.openai_api_key,
      llm_options: {
        chat_completion_model_name: 'gpt-4-turbo',
        embeddings_model_name: 'text-embedding-3-small'
      }
    )

    @connection = Langchain::Vectorsearch::Qdrant.new(
      url: ENV.fetch('QDRANT_URL', 'http://qdrant:6333'),
      api_key: ENV.fetch('QDRANT_API_KEY', ''),
      index_name: 'bezirkr',
      llm: llm
    )
    @connection.create_default_schema
  end

end
