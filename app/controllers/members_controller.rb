# frozen_string_literal: true

class MembersController < ApplicationController
  def index
    @members = @district.members.includes(:group).ordered_by_kind_and_name.group_by(&:group)
    @groups = @members.keys.sort_by{ it.members.elected.count }
  end
end
