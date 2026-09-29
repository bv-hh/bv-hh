# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :basic_auth, if: proc { Rails.application.credentials.dig(Rails.env.to_sym, :basic_auth) }

  before_action :lookup_district
  after_action :track_event

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
  end

  def default_url_options
    { district: @district&.name&.parameterize }
  end

  # For pages that only exist within a district. Without one in the path (bots
  # probing /documents or /statistics) there is nothing to show.
  def require_district
    raise ActionController::RoutingError, "#{request.path} needs a district" if @district.nil?
  end

  def without_district
    redirect_to url_for(district: nil), status: :moved_permanently and return false if params[:district].present?
  end

  # [Topic, count] pairs for the documents the block returns. Counting walks
  # every document of a district or Stadtteil, and the counts only move when
  # documents are fetched or classified, so an hour's staleness is fine.
  def cached_topic_counts(*key)
    counts = Rails.cache.fetch(['topic_counts', Topic::VERSION, *key], expires_in: 1.hour) { yield.topic_counts }
    Topic.ranked(counts)
  end

  def track_event
    ahoy.track 'Action', request.path_parameters
  end
end
