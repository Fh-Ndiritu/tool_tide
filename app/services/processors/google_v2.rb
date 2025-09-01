module Processors
  class GoogleV2
    include ImageModifiable

    def initialize(id)
      @landscape_request = LandscapeRequest.find(id)
      @landscape = @landscape_request.landscape
    end

    def self.perform(*args)
      new(*args).process
    end

    def process
      # we expect mask validations to be done ealier
      @landscape_request.preparing_request!
      apply_mask_for_transparency

      raise "Image blend not found" unless @landscape_request.reload.full_blend.attached?

      @landscape_request.generating_images!
      response = fetch_gcp_response
      validate_response(response)

      @landscape_request.saving_results!
      save_b64_results(response["predictions"])
      @landscape_request.processed!
    rescue StandardError => e
      raise "Google Processor failed with: #{e.message}"
    end

    private

    def validate_response(response)
      return if response.is_a?(Hash) && response["predictions"].present?

      raise "Response is invalid"
    end

    def fetch_gcp_response
      location = ENV.fetch("GOOGLE_LOCATION")
      endpoint = "https://#{location}-aiplatform.googleapis.com/v1/projects/#{ENV.fetch('GOOGLE_PROJECT_ID')}/locations/#{location}/publishers/google/models/imagen-3.0-capability-001:predict"
      Gcp::Client.new.send(endpoint, gcp_payload)
    end

    def save_b64_results(predictions)
      predictions.each do |prediction|
        b64_data = prediction["bytesBase64Encoded"]
        next if b64_data.blank?

        img_from_b64 = Base64.decode64(b64_data)
        extension = prediction["mimeType"].split("/").last

        temp_file = Tempfile.new([ "modified_image", ".#{extension}" ], binmode: true)
        temp_file.write(img_from_b64)
        temp_file.rewind

        blob = ActiveStorage::Blob.create_and_upload!(
          io: temp_file,
          filename: "modified_image.#{extension}",
          content_type: prediction["mimeType"]
        )
        @landscape_request.modified_images.attach(blob)
        @landscape_request.save!
      end
    end

    def apply_mask_for_transparency
      original_image_data = @landscape.original_image.variant(:to_process).processed
      original_image = MiniMagick::Image.read(original_image_data.blob.download)

      mask_binary = @landscape_request.mask.download
      mask_image = MiniMagick::Image.read(mask_binary)

      unless original_image.dimensions == mask_image.dimensions
        mask_image.resize "#{original_image.width}x#{original_image.height}!"
      end

      save_full_blend(mask_image, original_image)
      save_partial_blend(mask_image, original_image)
      @landscape_request.save!
    rescue StandardError => e
      raise "#{__method__} failed with: #{e.message}"
    end

    def save_partial_blend(mask_image, original_image)
      mask_image.combine_options do |c|
        c.colorspace("Gray")
        c.threshold("50%")
      end

     mask_image.combine_options do |c|
      c.alpha "set"
      c.fill "rgba(0,0,0,0.7)"
      c.opaque "black"
    end

      # Composite the original image with the new semi-transparent mask
      masked_image = original_image.composite(mask_image) do |c|
        c.compose "Over"
      end

      blob = attach_blob(masked_image)

      @landscape_request.partial_blend.attach(blob)
    end

    def save_full_blend(mask_image, original_image)
      mask_image.combine_options do |c|
        c.colorspace("Gray")
        c.threshold("50%")
      end

      mask_image.transparent("white")

      masked_image = original_image.composite(mask_image) do |c|
        c.compose "Over"
      end

      blob = attach_blob(masked_image)

      @landscape_request.full_blend.attach(blob)
    end

    def gcp_payload
      {
        "instances": [
          {
            "prompt": gsub_prompt(@landscape_request.full_prompt),
            "referenceImages": [
              {
                "referenceType": "REFERENCE_TYPE_RAW",
                "referenceId": 1,
                "referenceImage": {
                  "bytesBase64Encoded": Base64.strict_encode64(@landscape_request.full_blend.download)
                }
              }
            ]
          }
        ],
        "parameters": {
          "sampleCount": 3
        }
      }
    end
  end
end
