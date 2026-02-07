module Agentic
  class InpaintTool < RubyLLM::Tool
    description "Modifies a specific area of an image based on a prompt."

    param :prompt, type: :string, desc: "Detailed description of the visual changes to apply."
    param :mask, type: :string, desc: "Description or data of the area to modify (optional).", required: false

    def initialize(project_layer, transformation_type: nil)
      @project_layer = project_layer
      @transformation_type = transformation_type
    end

    def execute(prompt:, mask: nil)
      Rails.logger.info("Agentic::InpaintTool executing with prompt: #{prompt}")

      user = @project_layer.user
      cost = GOOGLE_PRO_IMAGE_COST

      # Pre-charge before API call
      spending = charge_user!(user, cost)

      image_blob = @project_layer.display_image.blob
      response = generate_image(prompt, image_blob)

      if response[:success]
        save_result(response[:data], response[:mime_type], spending)
      else
        # Refund on failure
        refund_user!(user, cost, spending)
        "Error generating image: #{response[:error]}"
      end
    rescue => e
      # Refund on any exception
      refund_user!(user, cost, spending) if spending
      raise e
    end

    private

    def generate_image(prompt, image_blob)
      conn = Faraday.new(
        url: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent",
        headers: {
          "Content-Type" => "application/json",
          "x-goog-api-key" => ENV["GEMINI_API_KEYS"].split("____").sample
        }
      ) do |f|
        f.options.timeout = 120
      end

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

    def save_result(data, mime_type, spending)
      extension = mime_type.split("/").last
      temp_file = Tempfile.new([ "sketch_inpaint", ".#{extension}" ], binmode: true)
      temp_file.write(data)
      temp_file.rewind

      new_layer = @project_layer.project.project_layers.create!(
        parent: @project_layer,
        design: @project_layer.design,
        layer_type: :generated,
        generation_type: :intermediate,
        transformation_type: @transformation_type,
        progress: :complete
      )

      new_layer.image.attach(io: temp_file, filename: "sketch_inpaint.#{extension}", content_type: mime_type)

      # Update spending trackable to the new layer for better tracking
      spending.update!(trackable: new_layer) if spending

      RubyLLM::Content.new(
        "I have generated a new image based on your request. It is saved as layer #{new_layer.layer_number}."
      )
    end

    def charge_user!(user, cost)
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
          trackable: @project_layer  # Will be updated to new_layer on success
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

      Rails.logger.info("Agentic::InpaintTool refunded #{cost} credit(s) for layer #{@project_layer.id}")
    end
  end
end
