# frozen_string_literal: true

module MeetingHelper
  # How lists name a decision, with its icon and colour.
  Decision = Data.define(:label, :icon, :color)
  NOTED = Decision.new('zur Kenntnis genommen', 'dot-circle', 'secondary')
  ADOPTED = Decision.new('beschlossen', 'check-circle', 'success')
  AMENDED = Decision.new('geändert beschlossen', 'check-circle', 'info')
  REFERRED = Decision.new('überwiesen', 'arrow-alt-circle-right', 'warning')
  POSTPONED = Decision.new('vertagt', 'arrow-alt-circle-right', 'warning')
  DEFERRED = Decision.new('zurückgestellt', 'arrow-alt-circle-left', 'warning')
  REJECTED = Decision.new('abgelehnt', 'times-circle', 'danger')
  WITHDRAWN = Decision.new('zurückgezogen', 'arrow-alt-circle-down', 'secondary')

  # A decision as ALLRIS words it => how lists name it.
  DECISIONS = {
    'zur Kenntnis genommen' => NOTED,
    'ungeändert beschlossen' => ADOPTED,
    'beschlossen' => ADOPTED,
    'ungeändert beschlossen / überwiesen' => ADOPTED,
    'geändert beschlossen' => AMENDED,
    'geändert beschlossen / überwiesen' => AMENDED,
    'überwiesen' => REFERRED,
    'an Ausschuss überwiesen' => REFERRED,
    'an Fachausschuss verwiesen' => REFERRED,
    'vertagt' => POSTPONED,
    'vertagt / verbleibt' => POSTPONED,
    'zurückgestellt' => DEFERRED,
    'abgelehnt' => REJECTED,
    'zurückgezogen' => WITHDRAWN,
    'zurückgezogen / erledigt' => WITHDRAWN,
  }.freeze

  def meeting_format(content, meeting)
    return '' if content.nil?

    content = link_documents(content, meeting.district)

    Rinku.auto_link(content, :all, 'target="_blank"')
  end

  def meeting_result_badge(agenda_item)
    decision = DECISIONS[agenda_item.decision]
    return if decision.nil?

    link_to minutes_meeting_path(agenda_item.meeting, anchor: agenda_item.id), class: "text-#{decision.color}", title: agenda_item.decision, data: { bs_toggle: :tooltip } do
      icon(:fas, decision.icon)
    end
  end

  # What became of a Drucksache at the meeting that last discussed it, in words
  # for a list: the decision, or that the meeting is still to come. The darker
  # -emphasis colours, as the plain ones are too light for text.
  def decision_label(agenda_item)
    coming = agenda_item.decision.nil? && !agenda_item.meeting.date.past?
    return tag.span(icon(:far, 'calendar', 'auf der Tagesordnung'), class: 'text-body') if coming

    decision = DECISIONS[agenda_item.decision]
    return if decision.nil?

    tag.span(icon(:fas, decision.icon, decision.label), class: "text-#{decision.color}-emphasis")
  end

  # "heute", "morgen" or "in 12 Tagen".
  def days_until(date)
    case (days = (date - Time.zone.today).to_i)
    when 0 then 'heute'
    when 1 then 'morgen'
    else "in #{days} Tagen"
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
