# frozen_string_literal: true

blazer_auth = Rails.application.credentials.dig(Rails.env.to_sym, :admin_auth)
if blazer_auth
  ENV['BLAZER_USERNAME'] = blazer_auth[:username]
  ENV['BLAZER_PASSWORD'] = blazer_auth[:password]
end
