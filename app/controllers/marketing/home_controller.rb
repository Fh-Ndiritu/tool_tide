module Marketing
  class HomeController < MarketingController
    rate_limit to: 3, within: 1.minute, by: -> { request.ip }, name: "shortterm_home_index"
    rate_limit to: 8, within: 20.minutes, by: -> { request.ip }, name: "longterm_home_index"

    def index
      @mask_requests = MaskRequest.complete.everyone.order(id: :desc).limit(12)
    end
  end
end
