# frozen_string_literal: true

require_relative "boot"

require "rails/all"
# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ToolTide
  class Application < Rails::Application
    Rails.root.join("config/initializers/brevo_api_mailer.rb")
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.before_configuration do
      # Write credentials to /tmp to bypass read-only filesystem
      creds_path = "/tmp/google_credentials.json"

      if ENV["GOOGLE_JSON_CREDENTIALS"].present?
        File.write(creds_path, ENV["GOOGLE_JSON_CREDENTIALS"])
        # Set the path so the Google Cloud SDK picks it up automatically
        ENV["GOOGLE_APPLICATION_CREDENTIALS"] = creds_path
      end

      # Your existing Brevo requirement
      require Rails.root.join("config/initializers/brevo_api_mailer.rb")
    end
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.generators do |g|
      g.test_framework :rspec,
                       fixtures: true,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false,
                       controller_specs: true,
                       request_specs: false
    end

    config.exceptions_app = self.routes
  end
end
