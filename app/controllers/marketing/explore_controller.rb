module Marketing
  class ExploreController < MarketingController
    def index
      @mask_requests = MaskRequest.complete.everyone.order(id: :desc).limit(40)
    end
  end
end
