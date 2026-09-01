Rails.application.routes.draw do
  root "dashboard#show"
  get "/dashboard", to: "dashboard#show", as: :dashboard
  resources :imports, only: %i[index new create show edit update destroy] do
    collection { delete :month }
    member do
      post :process_file
      patch :payment, action: :update_payment
    end
  end
  resources :transactions, only: %i[index edit update]
  resources :credit_card_transactions, only: :index
  resources :categories, only: %i[index create edit update destroy]
  resources :reports, only: :index
end
