# frozen_string_literal: true

Rails.application.routes.draw do
  get "communities", to: "pages#communities"
  resources :audios
  post "onboarding/update", to: "onboarding#update"
  resources :favorites, only: [ :create, :destroy, :index ]
  scope "/designs" do
    get ":slug", to: "locations#show", as: :location, constraints: { slug: /[a-z0-9\-\_]+/ }
  end

  get "landscaping-guides/:slug", to: "landscaping_guides#show", as: :landscaping_guide



  resources :text_requests, except: [ :destroy, :create, :edit ]

  namespace :admin do
    resources :tags, only: :create
    resources :canvas, only: %i[create show]
    resources :text_requests, only: [ :index, :edit, :destroy, :show ]
    resources :mask_requests, only: [ :index, :edit, :destroy ]
    resources :sketch_requests, only: [ :index, :edit, :destroy, :show ]
    resources :blogs, only: [ :index, :new, :create, :show ]
    resources :public_assets, only: [ :index, :create, :destroy ]

    post "mask_requests/toggle_display"
    post "text_requests/toggle_display"
    post "sketch_requests/toggle_display"
  end

  resources :public_assets, only: :show, param: :uuid

  get "privacy-policy", to: "pages#privacy_policy"
  get "contact_us", to: "pages#contact_us"
  get :explore, to: "mask_requests#explore"
  get "features/brush-prompt-editor", to: "features#brush_prompt_editor"
  get "features/ai-prompt-editor", to: "features#ai_prompt_editor"
  get "features/preset-style-selection", to: "features#preset_style_selection"
  get "features/location-plant-suggestions", to: "features#location_plant_suggestions"
  get "features/drone-view-3d-perspective", to: "features#drone_view_3d_perspective"
  get "features/shopping-list-planting-guide", to: "features#shopping_list_planting_guide"
  get "features/sketch-to-3d-rendering", to: "features#sketch_to_3d_rendering"
  get "features/intuitive-onboarding", to: "features#intuitive_onboarding"
  get "city-design-inspiration", to: "features#city_design_inspiration"

  get "full-faq", to: "pages#full_faq"
  get :low_credits, to: "credits#low"

  get "/ojus-ai-vs-hadaa-ai", to: "competitors#ojus", as: :ojus

  resources :canvas, shallow: true, except: [ :index, :edit, :show ] do
    resources :sketch_requests, only: %i[create show] do
      post :new_mask_request, on: :member
    end

    resources :mask_requests do
      collection do
        patch :update_location
      end

      member do
        post :generate_planting_guide
        post :add_plant
        delete :remove_plant
      end
    end
  end

  resources :mask_requests, only: :index
  # Home routes
  get "redeem/:token", to: "credit_vouchers#redeem", as: :redeem_credit
  get "credits", to: "home#credits", as: :credits
  get "pricing", to: "pricing#index"
  get "paystack/callback", to: "payment_transactions#callback"

  resources :payment_transactions, only: :create
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: "users/registrations", sessions: "users/sessions" }

  mount ActionCable.server => "/cable"


  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  root "home#index"
end
