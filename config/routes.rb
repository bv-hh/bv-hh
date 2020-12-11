Rails.application.routes.draw do

  scope '(:district)' do
    resources :documents, only: %i[index show] do
      collection do
        get :search
        get :suggest
      end
    end

    root to: 'districts#show', as: :root_with_district
  end

  root to: 'districts#show'
end
