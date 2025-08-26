PAYSTACK_CLIENT = Faraday.new(
      url: ENV.fetch("PAYSTACK_BASE_URL", nil),
      headers:  { "Content-Type" => "application/json" }
      ) do |conn|
      conn.request :authorization, "Bearer", ENV.fetch("PAYSTACK_API_KEY", nil)
      conn.response :raise_error
    end
