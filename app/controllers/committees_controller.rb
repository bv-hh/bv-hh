class CommitteesController < ApplicationController

  def index
    @committees = Meeting.distinct.order(:committee).pluck(:committee)
  end

  def show
    @committee = params[:id]
    @meetings = Meeting.where(committee: params[:id]).latest_first
  end
end
