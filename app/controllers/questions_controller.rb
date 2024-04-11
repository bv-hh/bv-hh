class QuestionsController < ApplicationController
  def index
    redirect_to new_question_path
  end

  def new
  end

  def create
    @question = question
    qdrant = QdrantDb.new
    res = qdrant.connection.ask(question: @question)
    
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    @answer = markdown.render(res.raw_response['choices'].first['message']['content'])
  end

  private
  def question
    params[:question][:question]
  end

end
