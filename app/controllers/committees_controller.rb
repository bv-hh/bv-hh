# frozen_string_literal: true

class CommitteesController < ApplicationController
  def index
    @committees = @district.committees.open.order(:inactive, :order)
  end

  def show
    @committee = @district.committees.find(params[:id])
    @documents_timeline = @district.documents.committee(@committee).in_last_months(12).group_by_month('meetings.date').count
  end
end
