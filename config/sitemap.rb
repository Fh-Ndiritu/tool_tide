# frozen_string_literal: true

# Set the host name for URL creation
# SitemapGenerator::Sitemap.default_host = "https://hadaa.pro/"

# =========================================================
# TENANT A: THE CLEAN SEO DOMAIN (hadaa.pro)
# =========================================================
SitemapGenerator::Sitemap.default_host = "https://hadaa.pro"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/pro"
SitemapGenerator::Sitemap.create do
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.

  # Static Marketing Pages
  add "/about", priority: 0.8, changefreq: "monthly"
  add "/terms", priority: 0.5, changefreq: "yearly"
  add "/privacy", priority: 0.5, changefreq: "yearly"

  add contact_us_path, priority: 0.5, changefreq: "monthly"
  add faq_path, priority: 0.8, changefreq: "monthly"

  add pricing_path, priority: 0.8, changefreq: "weekly"

  # Explore
  add explore_path, priority: 0.9, changefreq: "daily"

  # Features Features
  add "/features/brush-prompt-editor", priority: 0.9, changefreq: "weekly"
  add "/features/ai-prompt-editor", priority: 0.9, changefreq: "weekly"
  add "/features/intuitive-onboarding", priority: 0.9, changefreq: "weekly"
  add "/features/location-plant-suggestions", priority: 0.9, changefreq: "weekly"
  add "/features/preset-style-selection", priority: 0.9, changefreq: "weekly"
  add "/features/drone-view-3d-perspective", priority: 0.9, changefreq: "weekly"
  add "/features/shopping-list-planting-guide", priority: 0.9, changefreq: "weekly"
  add "/features/project-studio", priority: 0.9, changefreq: "weekly"
end

# =========================================================
# TENANT B: THE LEGACY APP DOMAIN (hadaa.app)
# =========================================================
SitemapGenerator::Sitemap.default_host = "https://hadaa.app"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/app"
SitemapGenerator::Sitemap.create do
  # Public Entry Points
  add "/welcome", priority: 0.8, changefreq: "monthly"
  add "/users/sign_in", priority: 0.8, changefreq: "monthly"
  add "/users/sign_up", priority: 0.8, changefreq: "monthly"
  add "/privacy-policy", priority: 0.5, changefreq: "monthly"
end

# Disable default search engine pings to avoid legacy dependency issues
SitemapGenerator::Sitemap.search_engines = {}

IndexNowService.broadcast(
  host: "hadaa.pro",
  path: Rails.public_path.join("sitemaps", "pro", "sitemap.xml.gz")
)

IndexNowService.broadcast(
  host: "hadaa.app",
  path: Rails.public_path.join("sitemaps", "app", "sitemap.xml.gz")
)

# Recommended: rake sitemap:create
# Or: rake sitemap:refresh:no_ping
