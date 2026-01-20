# frozen_string_literal: true

# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://hadaa.pro/"

SitemapGenerator::Sitemap.create do
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.

  # Static Marketing Pages
  add privacy_policy_path, priority: 0.5, changefreq: "monthly"
  add contact_us_path, priority: 0.5, changefreq: "monthly"
  add faq_path, priority: 0.8, changefreq: "monthly"

  add pricing_path, priority: 0.8, changefreq: "weekly"

  # Explore
  add explore_path, priority: 0.9, changefreq: "daily"

  # Features Features
  add "/features/brush-prompt-editor", priority: 0.8, changefreq: "weekly"
  add "/features/ai-prompt-editor", priority: 0.8, changefreq: "weekly"
  add "/features/intuitive-onboarding", priority: 0.8, changefreq: "weekly"
  add "/features/location-plant-suggestions", priority: 0.8, changefreq: "weekly"
  add "/features/preset-style-selection", priority: 0.8, changefreq: "weekly"
  add "/features/drone-view-3d-perspective", priority: 0.8, changefreq: "weekly"
  add "/features/shopping-list-planting-guide", priority: 0.8, changefreq: "weekly"
end

IndexNowService.new.broadcast

# rake sitemap:refresh:no_ping
