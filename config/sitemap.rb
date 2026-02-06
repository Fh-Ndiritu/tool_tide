# frozen_string_literal: true

# =========================================================
# SINGLE DOMAIN CONFIGURATION (hadaa.app)
# =========================================================

SitemapGenerator::Sitemap.default_host = "https://hadaa.app"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps"

SitemapGenerator::Sitemap.create do
  # ============================
  # MARKETING PAGES
  # ============================
  add root_path, priority: 1.0, changefreq: "weekly"

  add "/about", priority: 0.8, changefreq: "monthly"
  add "/terms", priority: 0.5, changefreq: "yearly"
  add "/privacy", priority: 0.5, changefreq: "yearly"

  add contact_us_path, priority: 0.5, changefreq: "monthly"
  add faq_path, priority: 0.8, changefreq: "monthly"
  add pricing_path, priority: 0.9, changefreq: "weekly"
  add explore_path, priority: 0.9, changefreq: "daily"

  # ============================
  # FEATURES
  # ============================
  add features_project_studio_path, priority: 1.0, changefreq: "weekly"
  add features_sketch_to_3d_path, priority: 1.0, changefreq: "weekly"
  add features_biological_engine_path, priority: 1.0, changefreq: "weekly"
  add features_planting_guide_path, priority: 1.0, changefreq: "weekly"

  # ============================
  # APP ENTRY POINTS
  # ============================
  add new_user_session_path, priority: 0.8, changefreq: "monthly"
  add new_user_registration_path, priority: 0.8, changefreq: "monthly"
  # Note: /privacy-policy is likely the same as /privacy or handled by routes,
  # but keeping consistent with previous sitemap if it existed separately.
  # Checking routes: map to exact path if specific route exists, else ignore duplicates.
end

# Disable default search engine pings
SitemapGenerator::Sitemap.search_engines = {}

# Ping IndexNow for hadaa.app
IndexNowService.broadcast(
  host: "hadaa.app",
  path: Rails.public_path.join("sitemaps", "sitemap.xml.gz")
)
