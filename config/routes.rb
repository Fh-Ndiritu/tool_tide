Rails.application.routes.draw do
  resources :direct_uploads, only: [ :create ]
  post "landscaper/modify_image", to: "landscaper#modify_image"
  get "home/index"
  resources :landscaper, only: [ :index ]
  resources :images, only: [ :create, :index ]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  get "images/:source/:conversion", to: "images#new", as: :new_image
  get "images/extract_text", to: "images#extract_text", as: :extract_text_image
  post "images/extract", to: "images#extract", as: :extract_images

  # New resource for showing/downloading converted images
  resources :converted_images, only: [ :index ] do
    # Route for downloading a specific file by its unique identifier (e.g., filename)
    get "download/:filename", on: :collection, to: "converted_images#download", as: :download_file, constraints: { filename: /.*/ }
  end
end
