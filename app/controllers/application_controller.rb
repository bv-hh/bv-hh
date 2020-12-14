class ApplicationController < ActionController::Base

  before_action :basic_auth, if: proc { Rails.configuration.try(:basic_auth) }

  before_action :lookup_district

  protected

  def basic_auth
    authenticate_or_request_with_http_basic do |username, password|
      username == Rails.configuration.basic_auth.username &&
        password == Rails.configuration.basic_auth.password
    end
  end

  def lookup_district
    @district = District.lookup(params[:district]) if params[:district].present?
  end

  def default_url_options
    { district: @district&.name&.parameterize }
  end
end
