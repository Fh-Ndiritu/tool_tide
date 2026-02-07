module Agentic
  class UpscaleTool < RubyLLM::Tool
    description "Upscales an image to higher resolution."

    # No specific params for upscale, but adding a dummy optional one or just leaving empty if supported.
    # RubyLLM usually requires at least one param for tool calls in some versions? No, expected void is fine.
    # But to be safe, let's add an optional note.
    # No specific params for upscale, but adding a dummy optional one or just leaving empty if supported.
    # RubyLLM usually requires at least one param for tool calls in some versions? No, expected void is fine.
    # But to be safe, let's add an optional note.
    param :note, type: :string, desc: "Optional note for the upscale.", required: false

    def initialize(project_layer, transformation_type: nil)
      @project_layer = project_layer
      @design = project_layer.design
      @transformation_type = transformation_type
    end

    def execute(note: nil)
      Rails.logger.info("Agentic::UpscaleTool executing")

      # Get the latest layer in the design (could be the result of a previous tool)
      latest_layer = @design.project_layers.order(created_at: :desc).first || @project_layer
      user = latest_layer.user
      cost = GOOGLE_2K_UPSCALE_COST

      Rails.logger.info("Upscaling layer #{latest_layer.id} (layer_number: #{latest_layer.layer_number})")

      # Pre-charge before API call
      spending = charge_user!(user, cost, latest_layer)

      image_blob = latest_layer.display_image.blob
      response = upscale_image(image_blob)

      if response[:success]
        save_result(response[:data], response[:mime_type], latest_layer, spending)
      else
        # Refund on failure
        refund_user!(user, cost, spending)
        "Error upscaling image: #{response[:error]}"
      end
    rescue => e
      # Refund on any exception
      refund_user!(user, cost, spending) if spending
      raise e
    end

    private

    def upscale_image(image_blob)
      conn = Faraday.new(
        url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
        }
      ) do |f|
        f.options.timeout = 120
      end

      # Prompt for upscaling
      prompt = "Upscale this image to high resolution, enhancing details and sharpness while maintaining the original content exactly."

      payload = {
        "contents" => [
          {
            "parts" => [
              { "text" => prompt },
              {
                "inline_data" => {
                  "mime_type" => image_blob.content_type,
                  "data" => Base64.strict_encode64(image_blob.download)
                }
              }
            ]
          }
        ]
      }

      response = conn.post("", payload.to_json)

      if response.success?
        json = JSON.parse(response.body)
        candidate = json.dig("candidates", 0, "content", "parts", 0, "inlineData")

        if candidate
           { success: true, data: Base64.decode64(candidate["data"]), mime_type: candidate["mimeType"] }
        else
           { success: false, error: "No image data in response" }
        end
      else
        { success: false, error: "API Error: #{response.status} - #{response.body}" }
      end
    rescue => e
      { success: false, error: e.message }
    end

    def save_result(data, mime_type, source_layer, spending)
      extension = mime_type.split("/").last
      temp_file = Tempfile.new([ "sketch_upscale", ".#{extension}" ], binmode: true)
      temp_file.write(data)
      temp_file.rewind

      new_layer = source_layer.project.project_layers.create!(
        parent: source_layer,
        design: source_layer.design,
        layer_type: :generated,
        generation_type: :upscaled,
        transformation_type: @transformation_type,
        progress: :complete
      )

      new_layer.image.attach(io: temp_file, filename: "sketch_upscale.#{extension}", content_type: mime_type)

      # Update spending trackable to the new layer for better tracking
      spending.update!(trackable: new_layer) if spending

      RubyLLM::Content.new(
        "I have upscaled the image. It is saved as layer #{new_layer.layer_number}."
      )
    end

    def charge_user!(user, cost, trackable_layer)
      user.with_lock do
        if user.pro_engine_credits < cost
          raise "Insufficient credits"
        end

        user.pro_engine_credits -= cost
        user.save!

        CreditSpending.create!(
          user: user,
          amount: cost,
          transaction_type: :spend,
          trackable: trackable_layer
        )
      end
    end

    def refund_user!(user, cost, spending)
      return unless spending

      user.with_lock do
        user.pro_engine_credits += cost
        user.save!

        CreditSpending.create!(
          user: user,
          amount: cost,
          transaction_type: :refund,
          trackable: spending.trackable
        )
      end

      Rails.logger.info("Agentic::UpscaleTool refunded #{cost} credit(s) for layer #{@project_layer.id}")
    end
  end
end
