# frozen_string_literal: true

class AgendaItemsController < ApplicationController
  include ActionView::Helpers::TextHelper

  skip_after_action :track_event, only: :suggest

  MAX_SUGGESTIONS = 5

  def allris
    redirect_to root_path and return if @district.blank?

    @agenda_item = @district.agenda_items.find_by!(allris_id: params[:allris_id])
    redirect_to(minutes_meeting_path(@agenda_item.meeting, district: @agenda_item.district, anchor: @agenda_item.id))
  end

  def suggest
    root = @district&.agenda_items || AgendaItem.all
    root = root.includes(:district, { meeting: :committee })
    agenda_items = AgendaItem.minutes_prefix_search(params[:q], root).limit(MAX_SUGGESTIONS).load
    agenda_items = agenda_items.map do |agenda_item|
      {
        id: agenda_item.id,
        path: minutes_meeting_path(agenda_item.meeting, anchor: agenda_item.id),
        title: "#{agenda_item.number} #{agenda_item.title}",
        date: I18n.l(agenda_item.meeting.date),
        district: agenda_item.meeting.district.name,
        meeting: agenda_item.meeting.title,
        excerpt: excerpt(strip_tags(agenda_item.minutes), params[:q], radius: 50)
      }
    end
    render json: agenda_items
  end

end
