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

  # AgendaItem::OUTCOMES => how lists name them.
  OUTCOME_LABELS = {
    noted: NOTED,
    adopted: ADOPTED,
    amended: AMENDED,
    referred: REFERRED,
    postponed: POSTPONED,
    deferred: DEFERRED,
    rejected: REJECTED,
    withdrawn: WITHDRAWN,
  }.freeze

  def meeting_format(content, meeting)
    return '' if content.nil?

    content = link_documents(content, meeting.district)

    Rinku.auto_link(content, :all, 'target="_blank"')
  end

  def meeting_result_badge(agenda_item)
    decision = OUTCOME_LABELS[agenda_item.outcome]
    return if decision.nil?

    options = { class: "text-#{decision.color}", title: agenda_item.decision, data: { bs_toggle: :tooltip } }
    # Only items from ALLRIS have an anchor in the minutes.
    return tag.span(icon(:fas, decision.icon), **options) if agenda_item.allris_id.blank?

    link_to(minutes_meeting_path(agenda_item.meeting, anchor: agenda_item.id), **options) { icon(:fas, decision.icon) }
  end

  # What became of a Drucksache at a meeting, in words for a list: the
  # decision, or that the meeting is still to come. The darker
  # -emphasis colours, as the plain ones are too light for text.
  def decision_label(agenda_item)
    return tag.span(icon(:far, 'calendar', 'auf der Tagesordnung'), class: 'text-body') if agenda_item.coming?

    decision = OUTCOME_LABELS[agenda_item.outcome]
    return if decision.nil?

    tag.span(icon(:fas, decision.icon, decision.label), class: "text-#{decision.color}-emphasis")
  end

  # The agenda item a list row of a Drucksache shows, decision, committee and
  # date together: a coming meeting that has it on its agenda, or else the one
  # that decided (Document#deciding_agenda_item), so a later meeting that
  # recorded nothing neither hides the decision nor takes credit for it, or
  # else the latest. Load agenda_items with their meetings first.
  def listed_agenda_item(document)
    latest = document.latest_agenda_item
    return latest if latest.nil? || latest.coming?

    document.deciding_agenda_item || latest
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
