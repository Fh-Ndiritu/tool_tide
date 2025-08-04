source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"
gem "ruby-vips", "~> 2.2", ">= 2.2.4"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # linting packages used by github action
  gem "bundler-audit", "~> 0.9.2"

  gem "dotenv-rails"

  # Cops
  gem "rubocop", require: false
  gem "rubocop-performance", require: false # Checks for performance-related issues
  gem "rubocop-rspec", require: false # If you use RSpec for testing
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "erb_lint"
    gem "lefthook"
  gem "rails_best_practices"
  gem "web-console"
end


group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "database_cleaner-active_record"
  gem "rspec-rails", "~> 8.0.1"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
  gem "simplecov", require: false
  gem "webdrivers"
end

# Validating attached document
gem "active_storage_validations"

gem "faraday", "~> 2.13"

gem "kramdown", "~> 2.5"

gem "hexapdf", "~> 1.3"
# Bot prevention
gem "rack-attack"
gem "recaptcha"
# Framework for creating reusable, testable, & encapsulated view components
gem "view_component"

gem "tailwindcss-ruby", "~> 4.1"

gem "tailwindcss-rails", "~> 4.3"

gem "sitemap_generator", "~> 6.3"

gem "faraday-retry", "~> 2.3"

gem "mini_magick", "~> 5.2"
gem "rdoc", "6.14.2"
gem 'googleauth'
gem 'google-cloud-ai_platform-v1', '~> 0.35.0'

gem "geocoder", "~> 1.8"

gem "devise", "~> 4.9"
