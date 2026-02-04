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
  # TENANT A: THE CLEAN SEO DOMAIN (hadaa.pro)
  # =========================================================
  constraints DomainConstraint.new([ "hadaa.pro", "localhost" ]) do
    scope module: "marketing" do
      root to: "home#index", as: :marketing_root
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

      # Dynamic Robots.txt for SEO
      get "robots.txt", to: "seo#robots"
      get "sitemap.xml.gz", to: "seo#sitemap"
    end

    # Cross-Domain Auth Navigation
    get "login", to: redirect("https://hadaa.app/users/sign_in")
    get "signup", to: redirect("https://hadaa.app/users/sign_up")
  end

  # =========================================================
  # TENANT B: THE LEGACY APP DOMAIN (hadaa.app)
  # =========================================================
  constraints DomainConstraint.new([ "hadaa.app", "localhost" ]) do
    get "privacy-policy", to: "pages#privacy_policy"

    # App root (Login/Dashboard)
    resource :user_setting, only: [ :update ]

    authenticated :user do
      root to: "mask_requests#index", as: :authenticated_root
    end

    devise_scope :user do
      root to: "users/registrations#new"
    end

    resources :audios
    post "onboarding/update", to: "onboarding#update"
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

      # REDIRECT: Old public routes to marketing domain? Or 410?
      # For now, let them 410 if not defined, or we can redirect if critical.
      # User said "disable access to all landscaping guides prefix/routes". Matches 410.

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

    resources :payment_transactions, only: :create
    devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: "users/registrations", sessions: "users/sessions" }

    mount ActionCable.server => "/cable"



    # Robots.txt to block all crawling on app
    get "robots.txt", to: "application#robots"
    get "sitemap.xml.gz", to: "application#sitemap"

    # 410 Gone "Black Hole" for Old SEO Pages
    unless Rails.env.development?
      match "*path", to: "application#render_410", via: :all, constraints: lambda { |req|
       !req.path.start_with?("/assets") &&
       !req.path.start_with?("/rails") &&
       !req.path.start_with?("/404") &&
       !req.path.start_with?("/500")
      }
    end
  end

  # Global error handling matches (outside constraints if needed, but here inside app constraint or global?
  # Actually 404/500 are usually handled by exceptions app, but for routes:
  match "/404", to: "errors#not_found", via: :all
  match "/500", to: "errors#internal_server_error", via: :all
end
