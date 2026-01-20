require 'rails_helper'

RSpec.describe IndexNowService do
  let(:service) { described_class.new }
  let(:sitemap_path) { Rails.root.join("public", "sitemap.xml.gz") }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '.broadcast' do
    it 'instantiates and calls broadcast' do
      instance = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(instance)
      expect(instance).to receive(:broadcast)
      described_class.broadcast
    end
  end

  describe '#broadcast' do
    context 'when sitemap.xml.gz does not exist' do
      before do
        allow(File).to receive(:exist?).with(sitemap_path).and_return(false)
      end

      it 'logs a warning and returns' do
        service.broadcast
        expect(Rails.logger).to have_received(:warn).with(/not found/)
      end
    end

    context 'when sitemap exists but has no URLs' do
      before do
        allow(File).to receive(:exist?).with(sitemap_path).and_return(true)
        # Mock Zlib to return empty urlset
        xml_content = '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>'
        allow(Zlib::GzipReader).to receive(:open).and_yield(StringIO.new(xml_content))
      end

      it 'logs info and returns' do
        service.broadcast
        expect(Rails.logger).to have_received(:info).with(/No URLs found/)
      end
    end

    context 'when sitemap contains URLs' do
      let(:urls) { [ 'https://hadaa.app/', 'https://hadaa.app/about' ] }
      let(:xml_content) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>https://hadaa.app/</loc></url>
            <url><loc>https://hadaa.app/about</loc></url>
          </urlset>
        XML
      end

      before do
        allow(File).to receive(:exist?).with(sitemap_path).and_return(true)
        allow(Zlib::GzipReader).to receive(:open).and_yield(StringIO.new(xml_content))
      end

      it 'submits URLs to IndexNow' do
        expected_payload = {
        host: "hadaa.pro",
        key: "4db450da45524514ad47d1a067244edf",
        keyLocation: "https://hadaa.pro/4db450da45524514ad47d1a067244edf.txt",
        urlList: ["https://hadaa.app/", "https://hadaa.app/about"]
      }

        response_double = instance_double(Faraday::Response, success?: true, status: 200)
        allow(Faraday).to receive(:post).with("https://api.indexnow.org/indexnow").and_return(response_double)

        service.broadcast

        expect(Faraday).to have_received(:post) do |url, &block|
          req = Struct.new(:headers, :body).new({}, nil)
          block.call(req)
          expect(JSON.parse(req.body, symbolize_names: true)).to eq(expected_payload)
        end
        expect(Rails.logger).to have_received(:info).with(/submission successful/)
      end

      it 'logs error on failure' do
        response_double = instance_double(Faraday::Response, success?: false, status: 500, body: "Error")
        allow(Faraday).to receive(:post).and_return(response_double)

        service.broadcast

        expect(Rails.logger).to have_received(:error).with(/submission failed/)
      end
    end

    context 'when handling sitemap index' do
      let(:index_xml) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
             <sitemap><loc>https://hadaa.app/sitemap1.xml.gz</loc></sitemap>
          </sitemapindex>
        XML
      end
      let(:child_xml) do
         <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>https://hadaa.app/page1</loc></url>
          </urlset>
        XML
      end
      let(:child_path) { Rails.root.join("public", "sitemap1.xml.gz") }

      before do
        allow(File).to receive(:exist?).with(sitemap_path).and_return(true)

        # We need to distinguish calls to Zlib::GzipReader based on some context,
        # but since we can't easily match the block argument in standard RSpec `receive`,
        # we can mock `open` to check the path or use a sequence.
        # However, simpler is to mock the `read` behavior based on the file path logic in `extract_urls_from_path`
        # But `extract_urls_from_path` takes a path argument.

        # Let's mock `extract_urls_from_path` implementation details slightly or just the IO.
        # Since the service reads the file using Zlib, we have to be careful.

        # Strategy: Mock Zlib to return different content based on what file is being "opened".
        # But Zlib::GzipReader.open takes a path.

        allow(Zlib::GzipReader).to receive(:open).with(sitemap_path).and_yield(StringIO.new(index_xml))
        allow(File).to receive(:exist?).with(child_path).and_return(true)
        allow(Zlib::GzipReader).to receive(:open).with(child_path).and_yield(StringIO.new(child_xml))
      end

      it 'extracts URLs from child sitemaps' do
         response_double = instance_double(Faraday::Response, success?: true, status: 200)
         allow(Faraday).to receive(:post).and_return(response_double)

         service.broadcast

         expect(Faraday).to have_received(:post) do |_, &block|
           req = Struct.new(:headers, :body).new({}, nil)
           block.call(req)
           expect(req.body).to include("https://hadaa.app/page1")
         end
      end

      it 'logs warning if child sitemap is missing' do
        allow(File).to receive(:exist?).with(child_path).and_return(false)

        service.broadcast

        expect(Rails.logger).to have_received(:warn).with(/Child sitemap.*missing/)
      end
    end
  end
end
