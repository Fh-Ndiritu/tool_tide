class IndexNowService
  require "zlib"
  require "open-uri"

  INDEX_NOW_URL = "https://api.indexnow.org/indexnow"
  HOST = "hadaa.app"
  KEY = "a4c43fd6df474f61afcf7970f6352710"
  KEY_LOCATION = "https://#{HOST}/#{KEY}.txt"

  def self.broadcast
    new.broadcast
  end

  def broadcast
    path = Rails.root.join("public", "sitemap.xml.gz")
    unless File.exist?(path)
      Rails.logger.warn "IndexNow: sitemap.xml.gz not found at #{path}"
      return
    end

    urls = extract_urls_from_path(path)

    if urls.empty?
      Rails.logger.info "IndexNow: No URLs found to submit."
      return
    end

    Rails.logger.info "IndexNow: Found #{urls.size} URLs to submit."

    urls.each_slice(10_000) do |batch|
      submit_batch(batch)
    end
  end

  private

  def extract_urls_from_path(path)
    xml_content = Zlib::GzipReader.open(path) { |gz| gz.read }
    doc = Nokogiri::XML(xml_content)

    if doc.at_css("sitemapindex")
      # It's an index, we need to read the children
      child_urls = []
      doc.css("loc").each do |loc_node|
        child_url = loc_node.text
        # Assuming child sitemaps are local and follow standard naming in public/
        filename = File.basename(child_url)
        child_path = Rails.root.join("public", filename)
        if File.exist?(child_path)
          child_urls.concat(extract_urls_from_path(child_path))
        else
           Rails.logger.warn "IndexNow: Child sitemap #{child_path} found in index but missing on disk."
        end
      end
      child_urls.uniq
    else
      # It's a urlset
      doc.css("url > loc").map(&:text)
    end
  end

  def submit_batch(url_list)
    payload = {
      host: HOST,
      key: KEY,
      keyLocation: KEY_LOCATION,
      urlList: url_list
    }

    response = Faraday.post(INDEX_NOW_URL) do |req|
      req.headers["Content-Type"] = "application/json; charset=utf-8"
      req.body = payload.to_json
    end

    if response.success?
      Rails.logger.info "IndexNow submission successful: #{response.status}"
    else
      Rails.logger.error "IndexNow submission failed: #{response.status} - #{response.body}"
    end
  rescue StandardError => e
    Rails.logger.error "IndexNow error: #{e.message}"
  end
end
