# frozen_string_literal: true

class CommitteesController < ApplicationController
  def index
    @committees = @district.committees.open.order(:inactive, :order)
    @title = "Gremien und Ausschüsse der Bezirksversammlung #{@district.name}"
  end

  def show
    @committee = @district.committees.find(params[:id])
    @documents_timeline = @district.documents.committee(@committee).in_last_months(12).group_by_month('meetings.date').count
    @memberships = ordered_memberships(@committee)
    @title = "#{@committee.name} - #{@committee.district.name}"
  end

  private

  # Group members by party, ordering parties by their overall size (number of
  # regular members in the district), largest first; members without a party
  # last. Within a party, order by name.
  def ordered_memberships(committee)
    party_sizes = @district.members.active.regular.group(:party_id).count

    committee.memberships.active.joins(:member).merge(Member.active).includes(member: :party).sort_by do |membership|
      party_id = membership.member.party_id
      [party_id ? 0 : 1, party_id ? -party_sizes[party_id].to_i : 0, membership.member.party&.name.to_s, membership.member.name.to_s]
    end
  end
end
