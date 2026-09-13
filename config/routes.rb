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
  get '/district-politics' => 'pages#district_politics', as: :district_politics
  get '/participation' => 'pages#participation', as: :participation

  # Must stay ABOVE `scope '(:district)'`: that scope's :district segment is
  # greedy, so a /feed declared below it would route to districts#show with
  # district: 'feed'.
  get '/feed' => 'feeds#show', as: :feed
  get '/feed.rss' => 'feeds#show', defaults: { format: :rss }
  get '/streets/suggest' => 'streets#suggest', as: :suggest_streets

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

    resources :parties, only: %i[index show]

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

    # Catch-all: MUST stay last in this scope. It comes after every resources
    # block so a Quarter slug cannot shadow /hamburg-nord/documents, and after
    # the root above so the single-segment form /:quarter does not swallow
    # paths that fall through to districts#show. Anything added below this line
    # would be unreachable.
    get ':quarter' => 'quarters#show', as: :quarter
  end
end
