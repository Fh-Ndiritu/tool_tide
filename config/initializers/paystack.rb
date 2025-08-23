PAYSTACK_CLIENT = Faraday.new(
      url: ENV.fetch("PAYSTACK_BASE_URL"),
      headers:  { "Content-Type" => "application/json" }
      ) do |conn|
      conn.request :authorization, "Bearer", ENV.fetch("PAYSTACK_API_KEY")
      conn.response :raise_error
    end
