class DesignGenerator
  include Designable

  def initialize(mask_request)
    @mask_request = mask_request
    @connection = connection
  end

  def self.perform(*args)
    new(*args).generate
  end

  def generate
    @mask_request.preparing!
    @mask_request.purge_views
    @mask_request.overlay_mask

    @mask_request.main_view!
    main_view

    generate_secondary_views

  rescue Faraday::ServerError => e
    @mask_request.update error_msg: e.message, progress: :failed
  end

  private

  def main_view
    prompt = @mask_request.prompt
    image = @mask_request.overlay
    payload = gcp_payload(prompt:, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.main_view.attach(blob)
  end

  def generate_secondary_views
    @mask_request.rotating!
    rotate_view

    @mask_request.drone!
    drone_view

    @mask_request.processed!
    charge_generation
  end

  def rotate_view
    image = @mask_request.reload.main_view
    return unless  image.attached?

    payload = gcp_payload(prompt: rotated_landscape_prompt, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.rotated_view.attach(blob)
  end

  def drone_view
    image = @mask_request.reload.rotated_view
    return unless image.attached?

    payload = gcp_payload(prompt: aerial_landscape_prompt, image:)
    response = fetch_gcp_response(payload)
    blob = save_gcp_results(response)
    @mask_request.drone_view.attach(blob)
  end

  def connection
    Faraday.new(
      url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image-preview:generateContent",
      headers: {
        "Content-Type" => "application/json",
        "x-goog-api-key" => ENV["GEMINI_API_KEY"]
      }
    ) do |f|
      f.response :raise_error
      # Time to wait for the connection to open
      f.options.open_timeout = 30
      # Total time for the request to complete
      f.options.timeout = 120
      # Time to wait for a read to complete
      f.options.read_timeout = 120
    end
  end

  # def resize_mask
  #   original_image = MiniMagick::Image.read(image.blob.download)
  #   mask_file = MiniMagick::Image.read(mask.blob.download)
  #   return if original_image.dimensions == mask_file.dimensions

  #   mask_file.resize "#{original_image.width}x#{original_image.height}!"
  #   io_object = StringIO.new(mask_file.to_blob)

  #   blob = ActiveStorage::Blob.create_and_upload!(
  #     io: io_object,
  #     filename: "final_mask.png",
  #     content_type: "image/png"
  #   )
  #  mask.attach(blob)
  #  save!
  # end
end
