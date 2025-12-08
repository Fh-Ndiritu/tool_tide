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

  add privacy_policy_path, priority: 0.7, changefreq: "monthly"
  add contact_us_path, priority: 0.7, changefreq: "monthly"
  add explore_path, priority: 0.9, changefreq: "daily"
  add ojus_path, priority: 0.8, changefreq: "weekly"

  Tag.where(tag_class: :event).each do |event|
    add "/events/#{event.slug}", changefreq: "weekly", priority: 0.8
  end

  Tag.where(tag_class: :season).each do |season|
    add "/seasons/#{season.slug}", changefreq: "weekly", priority: 0.8
  end

  Location.find_each do |location|
    add "/designs/#{location.slug}", changefreq: "weekly", priority: 0.8
  end
end

# rake sitemap:refresh:no_ping
