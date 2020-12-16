class CommitteesController < ApplicationController
  def index
    @committees = @district.meetings.distinct.order(:committee).pluck(:committee)
  end

  def show
    @committee = params[:id]
    @meetings = @district.meetings.where(committee: params[:id]).latest_first
  end
end
