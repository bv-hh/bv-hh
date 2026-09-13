# frozen_string_literal: true

module FeedsHelper
  EXCERPT_LENGTH = 400

  def feed_title(query)
    return 'BV-HH — Drucksachen' if query.empty?

    places = [*query.quarters, *query.street_display_names]
    return "BV-HH — Drucksachen aus #{query.district.name}" if places.empty?

    title = "BV-HH — Drucksachen zu #{places.to_sentence}"
    query.district.present? ? "#{title} (#{query.district.name})" : title
  end

  def feed_description(query)
    if query.empty?
      'Es sind keine Stadtteile oder Straßen ausgewählt. Rufen Sie /feed auf, um einen Feed zusammenzustellen.'
    else
      "Neue Drucksachen der Hamburger Bezirksversammlungen. Auswahl — #{query.description}."
    end
  end

  # The params that reproduce this selection, for self-referencing links.
  def feed_link_params(query)
    { district: query.district&.to_param, quarters: query.quarters, streets: query.street_display_names }.compact_blank
  end

  def feed_item_description(document)
    [document.district.name, plain_excerpt(document.content)].compact_blank.join(' · ')
  end

  private

  # Allris content is HTML with entities in it. Rails' strip_tags leaves &nbsp;
  # as literal text, which Builder then escapes again into "&amp;nbsp;", and
  # CGI.unescapeHTML only knows the five core entities — so parse it instead.
  # [[:space:]] covers the non-breaking space that decoding produces; squish
  # does not.
  def plain_excerpt(content)
    return nil if content.blank?

    Nokogiri::HTML.fragment(content).text.gsub(/[[:space:]]+/, ' ').strip.truncate(EXCERPT_LENGTH)
  end
end
