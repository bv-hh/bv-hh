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

    link_to minutes_meeting_path(agenda_item.meeting, anchor: agenda_item.id), class: "text-#{color}", title: agenda_item.decision, data: { bs_toggle: :tooltip } do
      icon(:fas, icon)
    end
  end

  def meeting_minutes_link(meeting)
    link_to minutes_meeting_path(meeting), title: "Protokoll vom #{l meeting.date}", data: { bs_toggle: :tooltip, placement: :bottom } do
      icon(:far, 'file-powerpoint')
    end
  end

  def structured_data_for_meeting(meeting)
    {
      '@context': 'https://schema.org',
      '@type': 'Event',
      name: meeting.title,
      startDate: meeting.starts_at.iso8601,
      endDate: meeting.ends_at.iso8601,
      eventAttendanceMode: 'https://schema.org/OfflineEventAttendanceMode',
      eventStatus: 'https://schema.org/EventScheduled',
      location: {
        '@type': 'Place',
        name: meeting.room,
        address: {
          '@type': 'PostalAddress',
          streetAddress: meeting.location,
          addressLocality: 'Hamburg',
          addressRegion: 'HH',
          addressCountry: 'DE',
        },
      },
      description: meeting.agenda_items.map { "#{it.number} #{it.title}" }.join("\n"),
      offers: {
        '@type': 'Offer',
        price: 0,
      },
      performer: {
        '@type': 'Organization',
        name: meeting.committee.name,
        url: committee_url(meeting.committee),
      },
      organizer: {
        '@type': 'Organization',
        name: "Bezirksversammlung #{meeting.district.name}",
        url: root_with_district_url(district: meeting.district),
      },
    }
  end
end
