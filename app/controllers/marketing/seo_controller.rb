# frozen_string_literal: true

module Marketing
  class SeoController < MarketingController
    layout false

    def robots
      render plain: <<~ROBOTS
        User-agent: *
        Allow: /

        Sitemap: https://hadaa.pro/sitemap.xml.gz
      ROBOTS
    end
  end
end
