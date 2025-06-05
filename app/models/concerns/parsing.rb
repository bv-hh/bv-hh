# frozen_string_literal: true

module Parsing
  extend ActiveSupport::Concern

  SANITIZER = Rails::Html::SafeListSanitizer.new
  SCRUBBER = Rails::Html::TargetScrubber.new
  SCRUBBER.tags = %w[font tabref div iframe h1 h2]
  SCRUBBER.attributes = %w[class target cellpadding cellspacing width height type]

  XPATHS_TO_REMOVE = %w[.//script .//form comment()].freeze

  def clean_html(node)
    return nil if node.nil?

    node.xpath(*XPATHS_TO_REMOVE).remove
    cleaned = SANITIZER.sanitize(node.inner_html, scrubber: SCRUBBER)
    clean_styles(cleaned)
  end

  def clean_styles(html)
    cleaned = html.gsub(/font-family:([^;]*);/, '').gsub(/font-size:([^;]*);/, '')
    cleaned = cleaned.gsub(/line-height:([^;]*);/, '').gsub('color:#0000ff;', '')
    cleaned = cleaned.gsub(/margin-*([^:]*):([^;]*);/, '').gsub(/padding-*([^:]*):([^;]*);/, '')
    cleaned = cleaned.gsub(/text-indent([^:]*):([^;]*);/, '')
    cleaned = cleaned.gsub(%r{<span style="">(\s*)</span>}, '').gsub(%r{<p([^>]*)></p>}, '')
    cleaned = cleaned.gsub(%r{<span [^>]*></span>}, '')
    cleaned.gsub(' style="">', '>')
  end

  def clean_linebreaks(html)
    return nil if html.nil?

    html.gsub('<br>', "\n").gsub('<br/>', "\n").delete("\r").squish
  end

  def retrieve_xpath_div(html, xpath_content)
    clean_html(html.xpath("//span[contains(text(), '#{xpath_content}')]").first&.ancestors('div')&.first)&.sub(xpath_content, '')
  end

  def strip_tags(content)
    ActionController::Base.helpers.strip_tags(content)
  end
end
