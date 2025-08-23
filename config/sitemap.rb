# Set the host name for URL creation
SitemapGenerator::Sitemap.default_host = 'https://hadaa.app/'

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

  # <% CANONICAL_IMAGE_FORMATS.keys.each do |source| %>
  #  <% DESTINATION_IMAGE_FORMATS.each do |conversion| %>

  # add all image manipulation paths
  CANONICAL_IMAGE_FORMATS.keys.each do |source|
    DESTINATION_IMAGE_FORMATS.each do |conversion|
      next if source == conversion
      add new_images_path(source, conversion)
    end
  end

  add extract_text_images_path
end


# rake sitemap:refresh:no_ping
