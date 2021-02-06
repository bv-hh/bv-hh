# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :basic_auth, if: proc { Rails.application.credentials.dig(Rails.env.to_sym, :basic_auth) }

  before_action :lookup_district

  protected

  def basic_auth
    auth = Rails.application.credentials.dig(Rails.env.to_sym, :basic_auth)
    authenticate_or_request_with_http_basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, auth[:username]) &
        ActiveSupport::SecurityUtils.secure_compare(password, auth[:password])
    end
  end

  def lookup_district
    @district = District.lookup(params[:district]) if params[:district].present?
    @district = District.first if @district.blank?
  end

  def default_url_options
    { district: @district&.name&.parameterize }
  end

  def without_district
    redirect_to url_for(district: nil), status: :moved_permanently and return false if params[:district].present?
  end
end
