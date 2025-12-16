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
      # this initializer is required very early in the boot process in the environment settings
      # we can move it elsewhere to avoid double initialization but that should be memoized already
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
