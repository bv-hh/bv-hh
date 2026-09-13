# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom' do
  xml.channel do
    xml.title feed_title(@query)
    xml.link feed_url(format: :rss, **feed_link_params(@query))
    xml.description feed_description(@query)
    xml.language 'de'
    xml.lastBuildDate((@documents.first&.created_at || Time.zone.now).rfc822)
    xml.tag!('atom:link', rel: 'self', type: 'application/rss+xml',
                          href: feed_url(format: :rss, **feed_link_params(@query)))

    @documents.each do |document|
      xml.item do
        xml.title "#{document.number} — #{strip_tags(document.title)&.squish}"
        url = document_url(document, district: document.district)
        xml.link url
        xml.guid url, isPermaLink: 'true'
        # created_at is when BV-HH first saw the Drucksache, which is what makes
        # this an alert feed rather than a reading list.
        xml.pubDate document.created_at.rfc822
        xml.description feed_item_description(document)
        xml.category document.kind if document.kind.present?
      end
    end
  end
end
