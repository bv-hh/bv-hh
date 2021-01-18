# frozen_string_literal: true

class GenerateSitemapJob < ApplicationJob
  def perform(*_args)
    SitemapGenerator::Interpreter.run verbose: false
    SitemapGenerator::Sitemap.ping_search_engines if Rails.env.production?
  end
end
