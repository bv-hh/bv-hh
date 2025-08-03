# frozen_string_literal: true

class Api::V1::BaseController < ApplicationController
  protect_from_forgery with: :null_session
  before_action :set_default_format

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def set_default_format
    request.format = :json
  end

  def render_error(message, status = :bad_request)
    render json: { error: message }, status: status
  end

  def render_not_found(message = 'Resource not found')
    render json: { error: message }, status: :not_found
  end
end
