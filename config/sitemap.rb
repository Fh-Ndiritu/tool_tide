# frozen_string_literal: true

# =========================================================
# TENANT A: THE CLEAN SEO DOMAIN (hadaa.pro)
# =========================================================
# Use a dedicated LinkSet to prevent state leakage
hadaa_pro = SitemapGenerator::LinkSet.new
hadaa_pro.default_host = "https://hadaa.pro"
hadaa_pro.sitemaps_path = "sitemaps/pro"
hadaa_pro.create do
  # Static Marketing Pages
  add "/about", priority: 0.8, changefreq: "monthly"
  add "/terms", priority: 0.5, changefreq: "yearly"
  add "/privacy", priority: 0.5, changefreq: "yearly"

  add contact_us_path, priority: 0.5, changefreq: "monthly"
  add faq_path, priority: 0.8, changefreq: "monthly"

  add pricing_path, priority: 0.8, changefreq: "weekly"

  # Explore
  add explore_path, priority: 0.9, changefreq: "daily"

  # Features
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
hadaa_app = SitemapGenerator::LinkSet.new
hadaa_app.default_host = "https://hadaa.app"
hadaa_app.sitemaps_path = "sitemaps/app"
hadaa_app.create do
  # Public Entry Points
  add "/users/sign_in", priority: 0.8, changefreq: "monthly"
  add "/users/sign_up", priority: 0.8, changefreq: "monthly"
  add "/privacy-policy", priority: 0.5, changefreq: "monthly"
end

# Disable default search engine pings via global config to rely on manual pings below
SitemapGenerator::Sitemap.search_engines = {}

# Ping IndexNow
IndexNowService.broadcast(
  host: "hadaa.pro",
  path: Rails.public_path.join("sitemaps", "pro", "sitemap.xml.gz")
)

IndexNowService.broadcast(
  host: "hadaa.app",
  path: Rails.public_path.join("sitemaps", "app", "sitemap.xml.gz")
)

# Recommended: rake sitemap:create
