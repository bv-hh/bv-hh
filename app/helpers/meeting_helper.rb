# frozen_string_literal: true

module MeetingHelper
  def meeting_format(content, meeting)
    return '' if content.nil?

    content = link_documents(content, meeting.district)

    Rinku.auto_link(content, :all, 'target="_blank"')
  end

  def meeting_result_badge(agenda_item)
    icon, color = case agenda_item.decision
    when 'zur Kenntnis genommen'
      %w[dot-circle secondary]
    when 'ungeändert beschlossen', 'beschlossen', 'ungeändert beschlossen / überwiesen'
      %w[check-circle success]
    when 'geändert beschlossen', 'geändert beschlossen / überwiesen'
      %w[check-circle info]
    when 'vertagt', 'an Ausschuss überwiesen', 'an Fachausschuss verwiesen', 'vertagt / verbleibt'
      %w[arrow-alt-circle-right warning]
    when 'zurückgestellt'
      %w[arrow-alt-circle-left warning]
    when 'abgelehnt'
      %w[times-circle danger]
    when 'zurückgezogen', 'zurückgezogen / erledigt'
      %w[arrow-alt-circle-down secondary]
    else
      return nil
    end

    link_to minutes_meeting_path(agenda_item.meeting, anchor: agenda_item.id), class: "text-#{color}", title: agenda_item.decision, data: { toggle: :tooltip } do
      icon(:fas, icon)
    end
  end

  def meeting_minutes_link(meeting)
    link_to minutes_meeting_path(meeting), title: "Protokoll vom #{l meeting.date}", data: { toggle: :tooltip, placement: :bottom } do
      icon(:far, 'file-powerpoint')
    end
  end
end
