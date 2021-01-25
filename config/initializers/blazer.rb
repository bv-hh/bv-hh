# frozen_string_literal: true

blazer_auth = Rails.application.credentials.dig(Rails.env.to_sym, :admin_auth)
if blazer_auth
  ENV['BLAZER_USERNAME'] = auth[:username]
  ENV['BLAZER_PASSWORD'] = auth[:password]
end
