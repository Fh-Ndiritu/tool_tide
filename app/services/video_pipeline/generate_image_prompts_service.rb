module VideoPipeline
  class ImagePromptListSchema < RubyLLM::Schema
    object :prompts do
      array :list, description: "List of image prompts" do
        object do
          string :prompt, description: "Detailed image generation prompt"
          integer :timestamp, description: "Timestamp in seconds for this prompt"
        end
      end
    end
  end

  class GenerateImagePromptsService
    def initialize(narration_scene)
      @narration_scene = narration_scene
    end

    def perform
      audio = @narration_scene.audio
      return unless audio&.audio_file&.attached?

      # Get duration using ffprobe
      file_path = ActiveStorage::Blob.service.path_for(audio.audio_file.key)
      duration = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{file_path}"`.to_f

      @narration_scene.update!(duration: duration.ceil)

      num_images = (duration / 10.0).ceil

      prompt = <<~PROMPT
        You are an expert visual storyteller and prompt engineer.
        We need to generate #{num_images} distinct image generation prompts for a video scene based on its narration.

        Scene Narration:
        "#{@narration_scene.narration_text}"

        Task:
        1. Analyze the narration and split it into #{num_images} sequential segments.
        2. For each segment, create a highly detailed image generation prompt that visualizes the content.
        3. Assign a timestamp to each prompt (starting at 0, incrementing by 10 seconds: 0, 10, 20...).

        Image Style & Vibe:
        - Style: Cinematic, Ancient Lore, Mythological, Hyper-realistic.
        - Visuals: High contrast, dramatic lighting (chiaroscuro), 8k resolution, highly detailed textures.
        - Mood: Somber, authoritative, mysterious, epic.
        - Composition: Wide shots for setting scenes, close-ups for emotional beats. Avoid text in images.

        Output Requirement:
        - Return exactly #{num_images} prompts.
        - Format as a JSON list of objects with 'prompt' and 'timestamp'.
      PROMPT

      response = RubyLLM.chat.with_schema(ImagePromptListSchema).ask(prompt)

      data = response.content["prompts"]["list"]

      ActiveRecord::Base.transaction do
        @narration_scene.image_prompts.destroy_all
        data.each do |prompt_data|
          @narration_scene.image_prompts.create!(
            prompt: prompt_data["prompt"],
            timestamp: prompt_data["timestamp"]
          )
        end
      end
    end
  end
end
