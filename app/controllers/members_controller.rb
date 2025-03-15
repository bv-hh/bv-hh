# frozen_string_literal: true

class MembersController < ApplicationController
  def show
    @member = @district.members.find(params[:id]&.split('-')&.last)
    full_member_path = member_path(@member, district: @member.district)
    redirect_to(full_member_path, status: :moved_permanently) and return unless request.path == full_member_path

    @title = "#{@member.name} - #{@member.kind} für #{@member.group.name} in der Bezirksversammlung #{@district.name}"
  end
end
