# frozen_string_literal: true

class PartiesController < ApplicationController
  def index
    @regular_counts = @district.members.active.regular.group(:party_id).count
    @parties = @district.parties.active.sort_by { |party| [-(@regular_counts[party.id] || 0), party.name] }
    @title = "Fraktionen und Gruppen der Bezirksversammlung #{@district.name}"
  end

  def show
    @party = @district.parties.find(params[:id]&.split('-')&.last)
    @members = @party.members.active.includes(memberships: :committee)
                     .sort_by { |member| [member.co_opted? ? 1 : 0, member.name.to_s] }
    @title = "#{@party.name} - #{@district.name}"
  end
end
