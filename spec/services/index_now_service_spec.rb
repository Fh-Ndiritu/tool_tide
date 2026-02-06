require 'rails_helper'

RSpec.describe IndexNowService do
  let(:host) { "hadaa.pro" }
  let(:path) { Rails.root.join("public", "sitemap.xml.gz") }

  before do
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '.broadcast' do
    it 'instantiates and calls broadcast with host and path' do
      instance = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(instance)
      expect(instance).to receive(:broadcast).with(host: host, path: path)
      described_class.broadcast(host: host, path: path)
    end
  end

  describe '#broadcast' do
    let(:service) { described_class.new }

    context 'when sitemap file does not exist' do
      before do
        allow(File).to receive(:exist?).with(path).and_return(false)
      end

      it 'logs a warning and returns' do
        service.broadcast(host: host, path: path)
        expect(Rails.logger).to have_received(:warn).with(/not found/)
      end
    end

    context 'when sitemap exists but has no URLs' do
      before do
        allow(File).to receive(:exist?).with(path).and_return(true)
        xml_content = '<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"></urlset>'
        allow(Zlib::GzipReader).to receive(:open).with(path).and_yield(StringIO.new(xml_content))
      end

      it 'logs info and returns' do
        service.broadcast(host: host, path: path)
        expect(Rails.logger).to have_received(:info).with(/No URLs found/)
      end
    end

    context 'when sitemap contains URLs' do
      let(:xml_content) do
        <<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
            <url><loc>https://hadaa.pro/</loc></url>
            <url><loc>https://hadaa.pro/about</loc></url>
          </urlset>
        XML
      end

      before do
        allow(File).to receive(:exist?).with(path).and_return(true)
        allow(Zlib::GzipReader).to receive(:open).with(path).and_yield(StringIO.new(xml_content))
      end

      it 'submits URLs to IndexNow' do
        response_double = instance_double(Faraday::Response, success?: true, status: 200)
        allow(Faraday).to receive(:post).and_return(response_double)

        service.broadcast(host: host, path: path)

        expect(Faraday).to have_received(:post)
        expect(Rails.logger).to have_received(:info).with(/submission successful/)
      end

      it 'logs error on failure' do
        response_double = instance_double(Faraday::Response, success?: false, status: 500, body: "Error")
        allow(Faraday).to receive(:post).and_return(response_double)

        service.broadcast(host: host, path: path)

        expect(Rails.logger).to have_received(:error).with(/submission failed/)
      end
    end
  end
end
