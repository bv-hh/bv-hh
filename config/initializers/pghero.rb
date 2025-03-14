# frozen_string_literal: true

pghero_auth = Rails.application.credentials.dig(Rails.env.to_sym, :admin_auth)
if pghero_auth
  ENV['PGHERO_USERNAME'] = pghero_auth[:username]
  ENV['PGHERO_PASSWORD'] = pghero_auth[:password]
end
