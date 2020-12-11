class ApplicationController < ActionController::Base

  before_action :lookup_district

  protected

  def lookup_district
    @district = District.lookup(params[:district]) if params[:district].present?
  end

  def default_url_options
    { district: @district&.name&.parameterize }
  end
end
