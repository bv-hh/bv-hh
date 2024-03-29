# frozen_string_literal: true

SitemapGenerator::Sitemap.default_host = 'https://bv-hh.de'

SitemapGenerator::Sitemap.sitemaps_path = 'system/'

SitemapGenerator::Sitemap.create do
  add '/home', changefreq: 'daily', priority: 0.9
  add '/contact_us', changefreq: 'weekly'

  Document.complete.find_each do |document|
    add document_path(document, district: document.district.name.parameterize), priority: 0.9
  end

  Meeting.complete.find_each do |meeting|
    add meeting_path(meeting, district: meeting.district.name.parameterize), priority: 0.5
    add minutes_meeting_path(meeting, district: meeting.district.name.parameterize)
  end

  District.find_each do |district|
    add root_with_district_path(district), priority: 0.3
  end
end
