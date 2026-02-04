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

    def sitemap
      # Serve the sitemap file from the public/sitemaps/pro directory
      path = Rails.public_path.join("sitemaps", "pro", "sitemap.xml.gz")
      if File.exist?(path)
        send_file path, type: "application/xml", disposition: "inline"
      else
        head :not_found
      end
    end
  end
end
