require 'rails_helper'

RSpec.describe LocationService do
  describe '.lookup' do
    let(:ip) { "8.8.8.8" }

    context 'when API returns successful response' do
      let(:response_body) do
        {
          "ipVersion" => 4,
          "ipAddress" => "8.8.8.8",
          "latitude" => 37.366,
          "longitude" => -122.0306,
          "countryName" => "United States of America",
          "countryCode" => "US",
          "timeZone" => "-08:00",
          "zipCode" => "94087",
          "cityName" => "Mountain View",
          "regionName" => "California",
          "isProxy" => false
        }.to_json
      end

      let(:response_double) { instance_double(Net::HTTPSuccess, is_a?: true, body: response_body) }

      before do
        allow(Net::HTTP).to receive(:get_response).with(URI("https://free.freeipapi.com/api/json/8.8.8.8")).and_return(response_double)
      end

      it 'returns a LocationResult object with correct data' do
        result = LocationService.lookup(ip)

        expect(result).to be_a(LocationService::LocationResult)
        expect(result.ip).to eq("8.8.8.8")
        expect(result.city).to eq("Mountain View")
        expect(result.state).to eq("California")
        expect(result.country).to eq("United States of America")
        expect(result.country_code).to eq("US")
        expect(result.latitude).to eq(37.366)
        expect(result.longitude).to eq(-122.0306)
      end
    end

    context 'when IP is localhost' do
      it 'returns nil' do
        expect(LocationService.lookup("127.0.0.1")).to be_nil
      end
    end

    context 'when API fails' do
      let(:response_double) { instance_double(Net::HTTPInternalServerError, is_a?: false, code: '500', message: 'Internal Server Error') }

      before do
        allow(Net::HTTP).to receive(:get_response).and_return(response_double)
      end

      it 'returns nil and logs error' do
        expect(Rails.logger).to receive(:error).with(/LocationService Error/)
        expect(LocationService.lookup(ip)).to be_nil
      end
    end
  end
end
