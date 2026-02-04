module Marketing
  class PagesController < MarketingController
    def contact_us
    end

    def full_faq
    end

    def privacy_policy
      render "pages/privacy_policy"
    end
  end
end
