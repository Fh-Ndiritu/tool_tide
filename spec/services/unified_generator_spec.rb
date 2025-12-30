require 'rails_helper'

RSpec.describe UnifiedGenerator do
  let(:user) { User.create!(email: "test@example.com", password: "password", password_confirmation: "password", privacy_policy: true) }
  let(:project) { Project.create!(title: "Test Project", user: user) }

  # Setup mock layers
  let(:mask_layer) do
    layer = project.layers.create!(layer_type: :mask)
    layer.image.attach(io: StringIO.new("fake_mask"), filename: "mask.png", content_type: "image/png")
    layer
  end

  let(:generation_layer) do
    project.layers.create!(
      layer_type: :generation,
      parent_layer: mask_layer,
      preset: "zen"
    )
  end

  let(:custom_layer) do
    project.layers.create!(
      layer_type: :generation,
      parent_layer: mask_layer,
      prompt: "A custom garden"
    )
  end

  describe "#generate" do
    before do
      allow_any_instance_of(UnifiedGenerator).to receive(:gcp_connection).and_return(double(post: double(body: {
        "candidates" => [
          {
            "content" => {
              "parts" => [
                {
                  "inlineData" => {
                    "mimeType" => "image/png",
                    "data" => Base64.encode64("fake_result_image")
                  }
                }
              ]
            }
          }
        ]
      }.to_json)))
    end

    it "constructs prompt from preset" do
      generator = UnifiedGenerator.new(generation_layer)

      # We expect the prompt to come from the preset config
      expected_prompt = YAML.load_file(Rails.root.join("config/prompts.yml")).dig("landscape_presets", "zen")

      expect(generator).to receive(:gcp_payload).with(
        hash_including(prompt: expected_prompt)
      ).and_call_original

      generator.generate
    end

    it "constructs prompt from custom prompt when preset is missing" do
      generator = UnifiedGenerator.new(custom_layer)

      expect(generator).to receive(:gcp_payload).with(
        hash_including(prompt: "A custom garden")
      ).and_call_original

      generator.generate
    end

    it "handles basic generation flow" do
      generator = UnifiedGenerator.new(generation_layer)
      expect {
        generator.generate
      }.to change { generation_layer.image.attached? }.from(false).to(true)
    end
  end
end
