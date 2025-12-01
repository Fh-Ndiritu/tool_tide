module VideoPipeline
  class GenerateAudioService
    def initialize(narration_scene)
      @narration_scene = narration_scene
    end

    def perform
      # Create Audio record. This will trigger the after_save_commit callback to generate audio via GeminiTts.
      # We need to ensure the content is serialized as a JSON string if the Audio model expects it,
      # or just pass the object if it handles JSON casting.
      # Looking at Audio model, it has `t.json "content"`, so Rails handles serialization.
      # However, GeminiTts expects `JSON.parse(@audio.content)` so it seems it might be stored as a string or the service expects a string.
      # Let's check Audio model again. It's `t.json`. Rails usually returns a Hash/Array for json columns.
      # But GeminiTts does `JSON.parse(@audio.content)`. If `@audio.content` is already a Hash/Array, `JSON.parse` will fail.
      # I should check if I need to fix GeminiTts or pass a string.
      # Given I cannot easily change GeminiTts without checking if it's used elsewhere,
      # I will assume for now I should pass it as a JSON string if GeminiTts parses it.
      # Wait, if `t.json` is used, `@audio.content` returns a ruby object.
      # If GeminiTts calls `JSON.parse`, it expects a string.
      # This implies `Audio` might be using `serialize` or just raw string in some cases, or GeminiTts is written assuming string storage.
      # Let's check GeminiTts again.
      content_json = @narration_scene.dialogue_content.to_json

      audio = Audio.create!(
        narration_scene_id: @narration_scene.id,
        content: content_json, # Passing string to be safe if GeminiTts parses it
        single_speaker: false
      )

      # The callback `generate_audio` in Audio model calls `GeminiTts.new(self).perform`
    end
  end
end
