# frozen_string_literal: true

class GroupsController < ApplicationController
  def index
    @groups = @district.groups.active.sort_by { -it.members.elected.count }
  end

  def show
    @group = @district.groups.find(params[:id]&.split('-')&.last)
    full_group_path = group_path(@group, district: @group.district)
    redirect_to(full_group_path, status: :moved_permanently) and return unless request.path == full_group_path

    @title = "#{@group.name} in der Bezirksversammlung #{@district.name}"
  end
end
