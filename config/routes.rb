Rails.application.routes.draw do

  scope '(:district)' do
    resources :documents, only: %i[index show] do
      collection do
        get :search
        get :suggest
      end
    end

    resources :meetings, only: %i[index show]

    resource :statistics, only: :show

    root to: 'districts#show', as: :root_with_district
  end

  root to: 'districts#show'
end
