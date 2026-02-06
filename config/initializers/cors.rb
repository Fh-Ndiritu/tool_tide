# frozen_string_literal: true

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://hadaa.app",
            "https://www.hadaa.app",
            "https://hadaa.app",
            "https://www.hadaa.app",
            "http://localhost:3000"

    resource "/assets/*",
      headers: :any,
      methods: [ :get, :head, :options ]

    # Allow access to packs (if using Webpack/Shakapacker)
    resource "/packs/*",
      headers: :any,
      methods: [ :get, :head, :options ]
  end
end
