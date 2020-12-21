# frozen_string_literal: true

class CommitteesController < ApplicationController
  def index
    @committees = @district.committees.open.order(:order)
  end

  def show
    @committee = @district.committees.find(params[:id])
  end
end
