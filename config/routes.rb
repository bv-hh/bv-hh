# frozen_string_literal: true

Rails.application.routes.draw do
  auth = Rails.application.credentials.dig(Rails.env.to_sym, :admin_auth)
  if auth.present?
    GoodJob::Engine.middleware.use(Rack::Auth::Basic) do |username, password|
      ActiveSupport::SecurityUtils.secure_compare(username, auth[:username]) &
        ActiveSupport::SecurityUtils.secure_compare(password, auth[:password])
    end
  end

  mount GoodJob::Engine, at: 'good_job'
  mount Blazer::Engine, at: 'blazer'
  mount PgHero::Engine, at: 'pghero'

  get '/about' => 'pages#about', as: :about
  get '/imprint' => 'pages#imprint', as: :imprint
  get '/privacy' => 'pages#privacy', as: :privacy
  get '/transparency' => 'pages#transparency', as: :transparency
  get '/mcp' => 'pages#mcp', as: :mcp

  get '/not_found' => 'errors#not_found', as: :foo
  get '/404' => 'errors#not_found', as: :not_found
  get '/500' => 'errors#exception', as: :exception

  post '/api/mcp' => 'mcp/server#index', as: :mcp_server

  root to: 'pages#home'

  scope '(:district)' do
    get :search, to: 'search#show'

    resources :documents, only: %i[index show] do
      collection do
        get :suggest

        get :allris
      end
    end

    resources :meetings, only: %i[index show] do
      collection do
        get :allris
      end

      member do
        get :minutes, path: 'protokoll'
      end
    end

    resources :agenda_items, only: [] do
      collection do
        get :allris
        get :suggest
      end
    end

    resources :committees, only: %i[index show]

    resource :calendar, only: :show

    resource :map, only: :show do
      collection do
        get :markers
      end
    end

    resources :locations, only: :show

    resource :statistics, only: :show

    resource :admin, only: :show, controller: :admin

    root to: 'districts#show', as: :root_with_district
  end
end
