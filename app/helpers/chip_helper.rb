# frozen_string_literal: true

# The small links and labels for places, Stadtteile, topics and Bezirke. Two
# rules keep them apart wherever they meet (/kitchensink shows them all):
#
# - The shape says what a chip is: a pill is a topic, a rounded rectangle a
#   place, Stadtteil or Bezirk. A place carries a pin, a Bezirk its town hall,
#   a Stadtteil nothing.
# - The fill says what it does: outline links to something or is an option not
#   chosen, filled gray is the chosen option, and filled with × is a filter to
#   remove. Every chip for a thing leads to it. Only the example searches
#   below a search field have colour; they are neither a thing nor a filter.
#
# dense: true takes the vertical padding off, for chips inside a list row or a
# card; a section of its own uses the default.
module ChipHelper
  def place_chip(location, dense: false)
    link_to location_path(location, district: location.district),
            class: ['btn btn-sm btn-outline-secondary', ('py-0' if dense)],
            title: location.formatted_address, data: { bs_toggle: :tooltip } do
      icon(:fas, 'map-marker-alt', location.name)
    end
  end

  def quarter_chip(quarter, dense: false)
    link_to quarter.name, quarter_path(district: quarter.district, quarter: quarter.slug),
            class: ['btn btn-sm btn-outline-secondary', ('py-0' if dense)]
  end

  # url is where the topic leads: its page, or the current list narrowed to it.
  def topic_chip(topic, url, dense: false, title: nil)
    link_to topic.label, url, class: ['btn btn-sm btn-outline-secondary rounded-pill', ('py-0' if dense)], title:
  end

  # One option of a filter over a list (Bezirke, topics), with its count. A
  # topic is a pill here too. current is the chosen one's aria-current: 'page'
  # where the options are pages of their own, as the Bezirke are.
  def filter_chip(label, url, selected:, count: nil, pill: false, current: 'true')
    link_to url, class: ['btn btn-sm text-nowrap', selected ? 'btn-secondary' : 'btn-outline-secondary', ('rounded-pill' if pill)],
                 'aria-current': (current if selected) do
      safe_join([label, (tag.span(number_with_delimiter(count), class: 'ms-1 opacity-75') if count)].compact)
    end
  end

  # Marks a result from another Bezirk than the one being browsed, among its
  # topics and places. url is the Bezirk's page unless given, such as the search
  # narrowed to the Bezirk.
  def district_chip(district, url = root_with_district_path(district:), dense: true)
    link_to url, class: ['btn btn-sm btn-outline-secondary', ('py-0' if dense)] do
      icon(:fas, 'landmark', district.name)
    end
  end

  # A filter in effect, named with its kind ("Thema: Verkehr"); × removes it.
  def filter_token(label, remove_url)
    tag.span(class: 'badge text-bg-secondary fs-6 fw-normal d-inline-flex align-items-center gap-2') do
      remove = link_to(remove_url, class: 'link-light text-decoration-none', title: "#{label} aufheben") do
        safe_join([tag.span('×', 'aria-hidden': 'true'), tag.span("#{label} aufheben", class: 'visually-hidden')])
      end
      safe_join([label, remove])
    end
  end

  # A search to start from.
  def example_chip(term)
    link_to search_path(q: term), class: 'btn btn-sm btn-example' do
      icon(:fas, 'search', term)
    end
  end
end
