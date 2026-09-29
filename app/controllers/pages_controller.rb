# frozen_string_literal: true

class PagesController < ApplicationController
  before_action :without_district

  def home
    @topic_counts = cached_topic_counts(:district, nil) { Document.complete }
  end

  def imprint; end

  def privacy; end

  def about; end

  def transparency; end

  def mcp; end

  def district_politics; end

  def participation; end
end
