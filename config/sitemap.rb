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

  # 104 genuinely distinct landing pages. The /feed config page deliberately
  # stays out: its URL space is combinatorial.
  Quarter.find_each do |quarter|
    district = quarter.district
    next if district.blank?

    add quarter_path(district: district.name.parameterize, quarter: quarter.slug),
        changefreq: 'weekly', priority: 0.6
  end
end
