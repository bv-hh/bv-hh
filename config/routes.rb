Rails.application.routes.draw do
  require 'sidekiq/web'
  require 'sidekiq-scheduler/web'

  auth = Rails.application.credentials.dig(Rails.env.to_sym, :sidekiq_auth)
  if auth.present?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, auth[:username]) &
        ActiveSupport::SecurityUtils.secure_compare(password, auth[:password])
    end
  end

  mount Sidekiq::Web => '/sidekiq'

  scope '(:district)' do
    resources :documents, only: %i[index show] do
      collection do
        get :search
        get :suggest
      end
    end

    resources :meetings, only: %i[index show]

    resources :committees, only: %i[index show]

    resource :statistics, only: :show

    root to: 'districts#show', as: :root_with_district
  end

  root to: 'districts#show'
end
