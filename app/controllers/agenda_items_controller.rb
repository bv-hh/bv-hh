# frozen_string_literal: true

class AgendaItemsController < ApplicationController

  def allris
    redirect_to root_path and return if @district.blank?

    @agenda_item = @district.agenda_items.find_by!(allris_id: params[:allris_id])
    redirect_to(minutes_meeting_path(@agenda_item.meeting, district: @agenda_item.district, anchor: @agenda_item.id))
  end
end
