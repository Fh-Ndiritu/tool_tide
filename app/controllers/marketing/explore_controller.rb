module Marketing
  class ExploreController < MarketingController
    def index
      @all_requests = MaskRequest.complete.everyone.main_view_variants.order(id: :desc)
      @cottage_requests = @all_requests.where(preset: "cottage").limit(20)
      @zen_requests = @all_requests.where(preset: "zen").limit(20)
      @desert_requests = @all_requests.where(preset: "desert").limit(20)
      @mediterranean_requests = @all_requests.where(preset: "mediterranean").limit(20)
      @tropical_requests = @all_requests.where(preset: "tropical").limit(20)
      @modern_requests = @all_requests.where(preset: "modern").limit(20)
    end
  end
end
