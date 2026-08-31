Rails.application.routes.draw do
  root "dashboard#show"
  get "/dashboard", to: "dashboard#show", as: :dashboard
  resources :imports, only: %i[index new create show destroy] do
    collection { delete :month }
    member { post :process_file }
  end
  resources :transactions, only: %i[index edit update]
  resources :categories, only: %i[index create edit update destroy]
  resources :reports, only: :index
end
