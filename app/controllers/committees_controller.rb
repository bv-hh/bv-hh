# frozen_string_literal: true

class CommitteesController < ApplicationController
  def index
    @committees = @district.committees.open.order(:inactive, :order)
    @title = "Gremien und Ausschüsse der Bezirksversammlung #{@district.name}"
  end

  def show
    @committee = @district.committees.find(params[:id])
    @documents_timeline = @district.documents.committee(@committee).in_last_months(12).group_by_month('meetings.date').count
    @memberships = @committee.memberships.joins(:member).merge(Member.active).includes(member: :party).order(:role, 'members.name')
    @title = "#{@committee.name} - #{@committee.district.name}"
  end
end
