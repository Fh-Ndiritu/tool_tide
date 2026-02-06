# frozen_string_literal: true

Rails.application.routes.draw do
  get "project_layers/show"
  get "project_layers/update"
  resources :projects, only: %i[index show create update new] do
    post :convert_to_project, on: :collection
    resources :designs, only: [ :create ] do
      resources :project_layers, only: [ :show, :create, :update ] do
        post :retry_generation, on: :member
        resources :auto_fixes, only: [ :create, :show ]
      end
    end
  end


  # Reveal health status on /up that otherwise be unable to shut down due to host constraint
  get "up" => "rails/health#show", as: :rails_health_check

  # =========================================================
  # MAIN APP ROUTES (hadaa.app)
  # =========================================================

  # Marketing Scope
  scope module: "marketing" do
    root to: "home#index"
    get "pricing", to: "pricing#index"

    # Marketing Pages
    get "contact_us", to: "pages#contact_us"
    get "faq", to: "pages#full_faq"
    get "about", to: "pages#about_us"
    get "terms", to: "pages#terms_of_service"
    get "privacy", to: "pages#privacy_policy"

    # Public Assets
    resources :public_assets, only: :show, param: :uuid

    # Features Pages
    get "features/brush-prompt-editor", to: "features#brush_prompt_editor", as: :features_brush_prompt_editor
    get "features/ai-prompt-editor", to: "features#ai_prompt_editor", as: :features_ai_prompt_editor
    get "features/preset-style-selection", to: "features#preset_style_selection", as: :features_preset_style_selection
    get "features/location-plant-suggestions", to: "features#location_plant_suggestions", as: :features_location_plant_suggestions
    get "features/drone-view-3d-perspective", to: "features#drone_view_3d_perspective", as: :features_drone_view_3d_perspective
    get "features/shopping-list-planting-guide", to: "features#shopping_list_planting_guide", as: :features_shopping_list_planting_guide
    get "features/intuitive-onboarding", to: "features#intuitive_onboarding", as: :features_intuitive_onboarding
    get "features/project-studio", to: "features#project_studio", as: :features_project_studio

    # Explore/Gallery
    get "explore", to: "explore#index", as: :explore
  end

  # Redirect legacy authentication paths if needed, or rely on Devise defaults
  # get "login", to: redirect("users/sign_in") # Optional if we want to alias

  get "privacy-policy", to: "marketing/pages#privacy_policy"

  # App root (Login/Dashboard)
  resource :user_setting, only: [ :update ]

  authenticated :user do
    root to: "mask_requests#index", as: :authenticated_root
  end

  devise_scope :user do
    # Fallback root for unauthenticated users is the marketing root defined above.
    # But if we want specific devise behavior:
    # root to: "users/registrations#new" # This conflicts with marketing root.
    # Let's keep marketing root as the main root for unauth users.
  end

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: "users/registrations", sessions: "users/sessions" }

  resources :audios
  post "onboarding/update", to: "onboarding#update"
  post "project_onboarding/update", to: "project_onboardings#update"

  get "welcome", to: "welcome#index", as: :welcome

  resource :onboarding_survey, only: [ :show, :update ], controller: "onboarding_survey"

  resources :favorites, only: [ :create, :destroy, :index ]

  resources :text_requests, except: [ :destroy, :create, :edit ]

  namespace :agora do
    resources :dashboard, only: [ :index ]
    resources :trends, only: [ :index ] do
      collection do
        post :hunt
      end
    end
    resources :posts, only: [ :show ] do
      collection do
        post :generate
      end
      member do
        post :vote
        post :proceed
      end
    end
    resources :executions, only: [ :index, :show, :update ] do
      post :generate_image, on: :member
      post :upload_analytics, on: :member
    end
    resources :brand_contexts, only: [ :index, :create ] do
      get :download, on: :member
    end
  end

  namespace :admin do
    resources :canvas, only: %i[create show]
    resources :text_requests, only: [ :index, :edit, :destroy, :show ]
    resources :mask_requests, only: [ :index, :edit, :destroy ]
    resources :blogs, only: [ :index, :new, :create, :show ]
    resources :public_assets, only: [ :index, :create, :destroy ]
    resources :social_posts, only: [ :index, :show, :update ] do
      post :generate, on: :collection
    end
    resources :projects, only: [ :index, :show ]

    post "mask_requests/toggle_display"
    post "text_requests/toggle_display"

    resource :hn_dashboard, only: :show, controller: "hn_dashboard"
  end

  resource :hn_dashboard, only: :show, controller: "hn_dashboard"

  get :low_credits, to: "credits#low"

  resources :canvas, shallow: true, except: [ :index, :edit, :show ] do
    resources :mask_requests do
      collection do
        patch :update_location
      end

      member do
        post :generate_planting_guide
        get :preferences
      end
    end
  end

  resources :mask_requests, only: :index
  # Home routes
  get "redeem/:token", to: "credit_vouchers#redeem", as: :redeem_credit
  get "credits", to: "home#credits", as: :credits

  get "paystack/callback", to: "payment_transactions#callback"
  get "stripe/callback", to: "payment_transactions#callback", as: :stripe_callback

  resources :payment_transactions, only: :create

  mount StripeEvent::Engine, at: "/stripe/webhooks"
  mount ActionCable.server => "/cable"

  # Robots and Sitemap
  # Note: seo#robots and seo#sitemap were in marketing scope. application#robots/sitemap in app scope.
  # We should consolidate to one controller. Let's stick to the application one as it's likely more generic.
  get "robots.txt", to: "application#robots"
  get "sitemap.xml.gz", to: "application#sitemap"

  # =========================================================
  # EXPLICIT 410 GONE ROUTES (Moved from Legacy PSEO)
  # =========================================================
  [ "designs", "landscaping-guides", "seasons", "events", "images" ].each do |prefix|
    match "/#{prefix}/*path", to: "application#render_410", via: :all
    match "/#{prefix}", to: "application#render_410", via: :all
  end

  # 410 Gone "Black Hole" for Old SEO Pages (Catch-all for weird stuff not matched above)
  # We might strictly rely on the explicit list above, OR keep the catch-all for safety.
  # Keeping catch-all for now but ensuring it doesn't block assets/active storage
  unless Rails.env.development?
    match "*path", to: "application#render_410", via: :all, constraints: lambda { |req|
      !req.path.start_with?("/assets") &&
      !req.path.start_with?("/rails") &&
      !req.path.start_with?("/up") &&
      !req.path.start_with?("/cable") &&
      !req.path.start_with?("/404") &&
      !req.path.start_with?("/500")
    }
  end

  # Errors
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
end
