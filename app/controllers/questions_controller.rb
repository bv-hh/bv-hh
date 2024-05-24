# frozen_string_literal: true

class QuestionsController < ApplicationController
  def index
    redirect_to new_question_path
  end

  def new; end

  def create
    @question = question
    qdrant = QdrantDb.new
    res = qdrant.connection.ask(question: wrap_question_in_default_prompt(question))

    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    @answer = markdown.render(res.raw_response['choices'].first['message']['content'])
  end

  private

  def question
    params[:question][:question]
  end

  def wrap_question_in_default_prompt(question)
    "You are a helpful press official, politely and swiftly answering questions from interested citizens.\
    Answer in the language that the question is in.\
    Here comes the question: #{question}"
  end
end
