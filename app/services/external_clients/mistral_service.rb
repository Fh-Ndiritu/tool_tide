# frozen_string_literal: true

module ExternalClients
class MistralService
  include Singleton

  def initialize
    @model = 'mistral-ocr-latest'
    @conn = conn
  end

  def image_ocr(base64_image)
    payload = fetch_image_payload(base64_image)
    response = fetch_request(payload)
    if response.success?
      Result.new(success: true, data: response.body)
    else
      raise "OCR request failed with status #{response.status}: #{response.body}"
    end
  rescue Faraday::Error => e
    raise "Network error occurred: #{e.message}"
  rescue JSON::ParserError => e
    raise "Failed to parse JSON response: #{e.message}"
    rescue StandardError => e
    raise "#{self.class.name} encountered an unexpected error:} #{e.message}"
  end

  # def perform(base64_pdf, json_output_file)
  #   payload = {
  #     model: "mistral-ocr-latest",
  #     document: {
  #       type: "document_url",
  #       document_url: "data:application/pdf;base64,#{base64_pdf}"
  #     },
  #     include_image_base64: true
  #   }

  #   response = conn.post do |req|
  #     req.headers["Content-Type"] = "application/json"
  #     req.headers["Authorization"] = "Bearer #{ENV['MISTRAL_API_KEY']}"
  #     req.body = payload.to_json
  #   end

  #   if response.success?
  #     json_output_file = write_response_to_file(response.body, json_output_file)
  #     convert_to_html(json_output_file)
  #   else
  #     raise "OCR request failed with status #{response.status}: #{response.body}"
  #   end
  # rescue Faraday::Error => e
  #   raise "Network error occurred: #{e.message}"
  # rescue JSON::ParserError => e
  #   raise "Failed to parse JSON response: #{e.message}"
  # end

  private


  def fetch_image_payload(base64_image)
    {
      model: @model,
      document: {
        type: 'image_url',
        image_url: "data:image/png;base64,#{base64_image}"
      },
      include_image_base64: true
    }
  end

  def fetch_request(payload)
    @conn.post do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{ENV['MISTRAL_API_KEY']}"
      req.body = payload.to_json
    end
  end

  def conn
    Faraday.new(url: 'https://api.mistral.ai/v1/ocr') do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  def write_response_to_file(response_body, json_output_file)
    output_dir = 'outputs/basic_ocr'
    FileUtils.mkdir_p(output_dir) unless Dir.exist?(output_dir)

    output_path = File.join(output_dir,  json_output_file)
    File.open(output_path, 'w') do |file|
      file.write(JSON.pretty_generate(response_body))
    end
    puts "OCR result written to #{output_path}"
    output_path
  rescue IOError => e
    raise "Failed to write OCR result to file: #{e.message}"
  end
end
end
