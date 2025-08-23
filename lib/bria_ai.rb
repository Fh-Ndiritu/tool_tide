# lib/bria_ai.rb
# This file defines the BriaAi module, its configuration, custom error classes,
# and the API client using Faraday for robust HTTP requests.

require 'faraday'
require 'faraday/retry' # Required for automatic retry logic
require 'json' # Required for JSON parsing, though Faraday::Response::Json usually handles it

# Main module for Bria AI integration.
module BriaAi
  # Base error class for all Bria AI specific exceptions.
  class Error < StandardError; end
  # Raised when authentication (API token) fails or is forbidden (401/403).
  class AuthenticationError < Error; end
  # Raised when rate limits are exceeded (429).
  class RateLimitError < Error; end
  # Raised for other API-specific errors (e.g., 400, 422, 5xx not handled by retry).
  class APIError < Error; end
  # Raised if the configuration is missing essential parameters.
  class ConfigurationError < Error; end

  # Configuration class for the Bria AI gem.
  # Allows setting global parameters like API token, base URL, and logger.
  class Configuration
    attr_accessor :api_token, :base_url, :logger, :default_sync_mode, :retry_options

    def initialize
      # Default base URL for Bria AI API.
      @base_url = 'https://engine.prod.bria-api.com/'
      # Default to asynchronous processing (sync: false) as recommended for performance.
      # Jobs might prefer sync: true for simplicity of immediate results.
      @default_sync_mode = false
      # Default logger outputs to STDOUT. In Rails, this would be Rails.logger.
      @logger = Logger.new(STDOUT)
      # Default retry options for Faraday::Retry middleware.
      @retry_options = {
        max: 3, # Maximum number of retry attempts.
        interval: 0.05, # Base interval in seconds for exponential backoff.
        interval_randomness: 0.5, # Adds randomness to interval to prevent thundering herd.
        backoff_factor: 2, # Factor by which interval increases on each retry.
        exceptions: [
          Faraday::TimeoutError, Faraday::ConnectionFailed # Standard network errors.
          # Faraday::ClientError is caught by custom_error_handler, which then re-raises
          # specific BriaAi errors. The retry middleware should catch these too if re-raised
          # by custom_error_handler before it, but often it's configured to handle pre-middleware errors.
          # Listing them here as general network errors which retry should catch.
        ],
        # methods: Faraday::Retry::Middleware::REQUEST_METHODS, # Apply retry to all HTTP methods.
        retry_statuses: [ 429, 503, 504 ], # Retry on these specific HTTP status codes.
        # `retry_if` block allows custom logic for determining if a request should be retried.
        # Here, it leverages the default logic from Faraday::Retry for exceptions.
        retry_if: ->(env, exception) { Faraday::Retry::Middleware.retry_on_exception?(env, exception) }
      }
    end
  end

  # Class methods for the BriaAi module to manage configuration.
  class << self
    attr_accessor :configuration
  end

  # Yields the configuration object to a block, allowing users to configure the gem.
  # Example:
  #   BriaAi.configure do |config|
  #     config.api_token = ENV['BRIA_AI_API_TOKEN']
  #     config.logger = Rails.logger
  #   end
  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  # Default configuration setup. This ensures that if the user doesn't call
  # BriaAi.configure, the gem still has sensible defaults and attempts to
  # load the API token from environment variables.
  configure do |config|
    config.api_token = ENV['BRIA_AI_API_TOKEN'] # Assumes API token is in an environment variable
  end

  # The main client class for interacting with the Bria AI API.
  class Client
    attr_reader :connection

    # Initializes the Bria AI client.
    # @param api_token [String] Your Bria AI API token. If nil, uses the configured token.
    # @param base_url [String] The base URL for the Bria AI API. If nil, uses the configured URL.
    # @param logger [Logger] A logger instance. If nil, uses the configured logger.
    # @param default_sync_mode [Boolean] Whether API calls should default to synchronous.
    # @param retry_options [Hash] Options for the Faraday::Retry middleware.
    def initialize(api_token: nil, base_url: nil, logger: nil, default_sync_mode: nil, retry_options: nil)
      @api_token = api_token || BriaAi.configuration.api_token
      @base_url = base_url || BriaAi.configuration.base_url
      @logger = logger || BriaAi.configuration.logger
      @default_sync_mode = default_sync_mode || BriaAi.configuration.default_sync_mode
      @retry_options = retry_options || BriaAi.configuration.retry_options

      # Ensure API token is present.
      unless @api_token
        raise BriaAi::ConfigurationError, "Bria AI API token is not configured. Please set it via BriaAi.configure or ENV['BRIA_AI_API_TOKEN']."
      end

      # Set up the Faraday connection with necessary middleware.
      @connection = Faraday.new(url: @base_url) do |faraday|
        # Request middleware for encoding request bodies as JSON.
        faraday.request :json
        # Response middleware for parsing JSON responses.
        faraday.response :json, content_type: /\bjson$/
        # Response middleware that raises Faraday::ClientError or Faraday::ServerError for 4xx/5xx responses.
        faraday.response :raise_error

        # Add the retry middleware to handle transient failures.
        faraday.request :retry, @retry_options

        # Custom middleware for detailed logging of requests and responses.
        faraday.request :request_logger, @logger
        faraday.response :response_logger, @logger

        # Custom error handler to convert Faraday exceptions into specific BriaAi errors.
        faraday.response :custom_error_handler

        # Set mandatory headers.
        faraday.headers['api_token'] = @api_token
        faraday.headers['Content-Type'] = 'application/json'
        faraday.headers['Accept'] = 'application/json'

        # Use the default HTTP adapter (e.g., Net::HTTP).
        faraday.adapter Faraday.default_adapter
      end
    end

    # Helper method to prepare image input for API requests.
    # It detects if the input is a URL or a Base64 string and formats it correctly.
    # Removes the "data:image/png;base64," prefix if present in a Base64 string.
    # @param input_data [String] The image URL or Base64 string.
    # @return [Hash] A hash with either `:image_url` or `:image_file` key.
    def prepare_image_input(input_data)
      if input_data.to_s.start_with?('http://', 'https://')
        { image_url: input_data }
      elsif input_data.to_s.include?('data:') && input_data.to_s.include?('base64,')
        # Extract raw Base64 string by removing the data URI prefix.
        { file: input_data.split(',')[1] }
      else
        # Assume it's a raw Base64 string if no prefix or URL.
        { file: input_data }
      end
    end

    # Helper method to prepare mask input for API requests.
    # Behaves similarly to prepare_image_input.
    # @param input_data [String] The mask URL or Base64 string.
    # @return [Hash] A hash with either `:mask_url` or `:mask_file` key.
    def prepare_mask_input(input_data)
      if input_data.to_s.start_with?('http://', 'https://')
        { mask_url: input_data, mask_type: 'manual' }
      elsif input_data.to_s.include?('data:') && input_data.to_s.include?('base64,')
        # Extract raw Base64 string by removing the data URI prefix.
        { mask_file: input_data.split(',')[1], mask_type: 'manual' }
      else
        # Assume it's a raw Base64 string if no prefix or URL.
        { mask_file: input_data, mask_type: 'manual' }
      end
    end

    # Calls the `/image-editing/gen-fill` endpoint to generate new objects
    # or modify images within a masked region, guided by a prompt.
    # @param image_input [String] The original image (URL or Base64).
    # @param mask_input [String] The mask defining the area to modify (URL or Base64).
    # @param prompt [String] The textual prompt guiding the AI generation.
    # @param negative_prompt [String, nil] Optional: Elements to avoid in generation.
    # @param num_results [Integer, nil] Optional: Number of results to generate (1-4).
    # @param sync [Boolean] Optional: Whether to process synchronously (default: configured value).
    # @param seed [Integer, nil] Optional: Seed for reproducibility.
    # @return [Faraday::Response] The API response object.
    def gen_fill(image_input:, mask_input:, prompt:, negative_prompt: nil, num_results: nil, sync: @default_sync_mode, seed: nil)
      payload = prepare_image_input(image_input).merge(prepare_mask_input(mask_input)).merge(
        prompt: prompt,
        sync: sync
      )
      payload[:negative_prompt] = negative_prompt if negative_prompt
      payload[:num_results] = num_results if num_results
      payload[:seed] = seed if seed

      @connection.post('/v1/gen_fill', payload)
    end

    # Calls the `/image-editing/eraser` endpoint for removing elements or masked areas.
    # @param image_input [String] The original image (URL or Base64).
    # @param mask_input [String] The mask defining the area to erase (URL or Base64).
    # @return [Faraday::Response] The API response object.
    def eraser(image_input:, mask_input:)
      payload = prepare_image_input(image_input).merge(prepare_mask_input(mask_input))
      @connection.post('image-editing/eraser', payload)
    end
  end # class Client

  # --- Custom Faraday Middleware ---

  # Faraday middleware for logging outgoing requests.
  class RequestLogger < Faraday::Middleware
    def initialize(app, logger)
      super(app)
      @logger = logger
    end

    def call(env)
      @logger.debug "[BriaAi] Request: #{env.method.upcase} #{env.url} | Headers: #{env.request_headers.inspect} | Body: #{env.body.inspect}"
      @app.call(env)
    end
  end
  Faraday::Request.register_middleware(request_logger: -> { RequestLogger })

  # Faraday middleware for logging incoming responses.
  class ResponseLogger < Faraday::Middleware
    def initialize(app, logger)
      super(app)
      @logger = logger
    end

    def call(env)
      @app.call(env).on_complete do |response_env|
        @logger.debug "[BriaAi] Response: #{response_env.status} | Headers: #{response_env.response_headers.inspect} | Body: #{response_env.body.inspect}"
      end
    rescue Faraday::Error => e
      @logger.error "[BriaAi] Request failed before response (e.g., connection issue): #{e.class}: #{e.message}"
      raise # Re-raise the exception after logging.
    end
  end
  Faraday::Response.register_middleware(response_logger: -> { ResponseLogger })

  # Faraday middleware for converting generic Faraday errors into specific BriaAi errors.
  class CustomErrorHandler < Faraday::Middleware
    def call(env)
      @app.call(env) # Pass the request through the middleware stack.
    rescue Faraday::ClientError => e # Catches 4xx and 5xx errors from raise_error middleware.
      status = e.response[:status]
      body = e.response[:body] || {} # Ensure body is a hash, or empty if nil.
      error_message = body['detail'] || body['message'] || body.to_s || 'An unknown API error occurred.'

      case status
      when 401, 403
        raise BriaAi::AuthenticationError, "Bria AI Authentication Error (Status: #{status}): #{error_message}"
      when 429
        # Faraday::Retry middleware should catch 429, but if it's exhausted retries, this will be the final error.
        raise BriaAi::RateLimitError, "Bria AI Rate Limit Exceeded (Status: #{status}): #{error_message}"
      when 400, 422 # Bad Request, Unprocessable Entity
        raise BriaAi::APIError, "Bria AI API Request Error (Status: #{status}): #{error_message}"
      when 500, 502, 503, 504 # Server errors
        # Faraday::Retry should handle 503, 504. If not caught, it's a persistent server error.
        raise BriaAi::APIError, "Bria AI Server Error (Status: #{status}): #{error_message}"
      else
        raise BriaAi::APIError, "Bria AI API Error (Status: #{status}): #{error_message}"
      end
    rescue Faraday::TimeoutError => e
      raise BriaAi::Error, "Bria AI API Timeout: #{e.message}"
    rescue Faraday::ConnectionFailed => e
      raise BriaAi::Error, "Bria AI API Connection Failed: #{e.message}"
    rescue StandardError => e # Catch any other unexpected errors from Faraday.
      raise BriaAi::Error, "An unexpected error occurred during Bria AI API call: #{e.class}: #{e.message}"
    end
  end
  Faraday::Response.register_middleware(custom_error_handler: -> { CustomErrorHandler })
end
