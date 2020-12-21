# frozen_string_literal: true

class CommitteesController < ApplicationController
  def index
    @committees = @district.committees.open.order(:order)
  end

  def show
    @committee = @district.committees.find(params[:id])
    @documents_timeline = @district.documents.committee(@committee).in_last_12_months.group_by_month('meetings.date').count
  end
end
