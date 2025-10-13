# frozen_string_literal: true

# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = "https://hadaa.app/"

SitemapGenerator::Sitemap.create do
  # Put links creation logic here.
  #
  # The root path '/' and sitemap index file are added automatically for you.
  # Links are added to the Sitemap in the order they are specified.
  #
  # Usage: add(path, options={})
  #        (default options are used if you don't specify)
  #
  # Defaults: :priority => 0.5, :changefreq => 'weekly',
  #           :lastmod => Time.now, :host => default_host
  #
  # Examples:
  #
  # Add '/articles'
  #
  #   add articles_path, :priority => 0.7, :changefreq => 'daily'
  #
  # Add all articles:
  #
  #   Article.find_each do |article|
  #     add article_path(article), :lastmod => article.updated_at
  #   end

  EVENTS.each do |event_name|
    # Convert the event name to a URL-friendly slug (e.g., "Diwali" -> "diwali")
    # You'll need to define a method or gem to handle the slugging in a real app,
    # but for a simple example:
    slug = event_name.downcase.gsub(/[^a-z0-9\s-]/, "").gsub(/\s+/, "-")

    # This assumes a route like /events/:slug (e.g., /events/diwali)
    add "/events/#{slug}", changefreq: "weekly", priority: 0.8
  end
end

# rake sitemap:refresh:no_ping
