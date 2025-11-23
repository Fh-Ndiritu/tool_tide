# frozen_string_literal: true

require "paypal_server_sdk"

include PaypalServerSdk

PaypalClient = PaypalServerSdk::Client.new(
  client_credentials_auth_credentials: ClientCredentialsAuthCredentials.new(
    o_auth_client_id: ENV.fetch("PAYPAL_CLIENT_ID", ""),
    o_auth_client_secret: ENV.fetch("PAYPAL_CLIENT_SECRET", "")
  ),

  environment: Environment.const_get(ENV.fetch("PAYPAL_ENVIRONMENT", "SANDBOX")),
  logging_configuration: LoggingConfiguration.new(
    mask_sensitive_headers: false,
    log_level: Logger::INFO,
    request_logging_config: RequestLoggingConfiguration.new(
      log_headers: true,
      log_body: true,
      ),
    response_logging_config: ResponseLoggingConfiguration.new(
      log_headers: true,
      log_body: true
    )
)
)
