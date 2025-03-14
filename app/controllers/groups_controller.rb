# frozen_string_literal: true

class GroupsController < ApplicationController
  def index
    @groups = @district.groups.active.sort_by { -it.members.elected.count }
  end
end
