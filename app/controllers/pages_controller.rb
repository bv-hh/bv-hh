# frozen_string_literal: true

class PagesController < ApplicationController
  before_action :without_district

  def imprint; end

  def privacy; end

  def about; end
end
