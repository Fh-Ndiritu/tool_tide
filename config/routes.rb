# frozen_string_literal: true

Rails.application.routes.draw do
  resources :text_requests, except: [ :destroy, :create, :edit ]

  namespace :admin do
    get "mask_requests/index"
    get "mask_requests/edit"
    post "mask_requests/toggle_display"
  end

  get "privacy-policy", to: "pages#privacy_policy"
  get "contact_us", to: "pages#contact_us"
  get :explore, to: "mask_requests#explore"
  get :low_credits, to: "credits#low"

  resources :canvas, shallow: true do
    resources :mask_requests
  end

  # Home routes
  get "credits", to: "home#credits", as: :credits
  get "paystack/callback", to: "payment_transactions#callback"

  resources :payment_transactions, only: :create
  devise_for :users

  mount ActionCable.server => "/cable"


  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
