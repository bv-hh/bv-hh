# frozen_string_literal: true

Rails.application.routes.draw do
  require 'sidekiq/web'
  require 'sidekiq-scheduler/web'

  auth = Rails.application.credentials.dig(Rails.env.to_sym, :admin_auth)
  if auth.present?
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, auth[:username]) &
        ActiveSupport::SecurityUtils.secure_compare(password, auth[:password])
    end
  end

  mount Sidekiq::Web => '/sidekiq'
  mount Blazer::Engine, at: 'blazer'

  get '/about' => 'pages#about', as: :about
  get '/imprint' => 'pages#imprint', as: :imprint
  get '/privacy' => 'pages#privacy', as: :privacy

  root to: 'pages#home'

  scope '(:district)' do
    resources :documents, only: %i[index show] do
      collection do
        get :search
        get :suggest
      end
    end

    resources :meetings, only: %i[index show] do
      member do
        get :minutes
      end
    end

    resources :committees, only: %i[index show]

    resource :statistics, only: :show

    root to: 'districts#show', as: :root_with_district
  end
end
