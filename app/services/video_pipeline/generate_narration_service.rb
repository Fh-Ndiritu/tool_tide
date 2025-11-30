module VideoPipeline
  class NarrationSchema < RubyLLM::Schema
    object :narration do
      string :text, description: "The full narration text in Vaatvidya style"
    end
  end

  class DialogueSchema < RubyLLM::Schema
    object :dialogue do
      array :blocks, description: "List of narration blocks" do
        object do
          string :style_prompt, description: "Style instructions for the voice actor (e.g. tone, pace)"
          array :turns, description: "List of dialogue turns" do
            object do
              string :speaker, description: "The speaker name (must be one of the provided available voices)"
              string :text, description: "The text spoken by the speaker"
            end
          end
        end
      end
    end
  end

  class GenerateNarrationService
    def initialize(narration_scene)
      @narration_scene = narration_scene
    end

    def perform
      generate_narration_text
      generate_dialogue_content
    end

    private

    def generate_narration_text
      prompt = <<~PROMPT
        Generate narration for the following scene overview:
        "#{@narration_scene.content_overview}"

        Use the style used by Popular Youtube Creator Vaatvidya to keep users engaged and intrigued in a Vaatvidya Narration Style.
        Maintain a fast standard clear narrative pace. The tone must be somber and authoritative, embodying the ancient lore aesthetic.
        Revise the content to ensure the story is profound, narrative and maintains our style.
      PROMPT

      response = RubyLLM.chat.with_schema(NarrationSchema).ask(prompt)
      @narration_scene.update!(narration_text: response.content["narration"]["text"])
    end

    def generate_dialogue_content
      # Character descriptions from VOICE_MAP comments
      character_descriptions = <<~DESC
        - Huria: Main Narrator/Default Voice (Neutral - Engaging/Warm Storyteller)
        - Karuri: Primary Male Character (Male - Clear, Steady Lead)
        - Mwangi: Tertiary Male Character (Male - Even, Mature Support)
        - Wairimu: Authority/Mature Character (Neutral - Experienced, Distinguished Tone)
        - Wanjiku: Primary Female Character (Female - Smooth, Dramatic Heroine)
        - Muthoni: Gentle Companion/Support (Female - Soft, Warm Tone)
        - Kariuki: Eccentric/Older Sidekick (Male - Gravelly, Distinct Tone)
        - Ndunge: Firm Authority/Second Narrator (Female - Firm, Commanding Tone)
        - Ndiangui: Mysterious/Excitable Character (Male - Breathy, Highly Emotive)
        - Chiru: High Energy/Youthful Character (Female - Bright, Cheerful, Enthusiastic)
      DESC

      available_voices = VOICE_MAP.keys.join(", ")

      prompt = <<~PROMPT
        Convert the following narration into a dialogue script.

        Narration:
        "#{@narration_scene.narration_text}"

        Character Descriptions:
        #{character_descriptions}

        Rules:
        1. The narrator will always be Huria.
        2. Select other speakers from the available voices list based on character type, Gender etc.
        3. Available voices: #{available_voices}.
        4. Structure the output as a list of blocks. Each block should have a 'style_prompt' and a list of 'turns'.
        5. For Huria (Narrator), prefer the style prompt: "Vaatvidya Narration Style. Maintain a fast standard clear narrative pace. The tone must be somber and authoritative, embodying the ancient lore aesthetic." but adapt it if the context requires (e.g. if the scene is very fast or slow).
        6. For other characters, generate appropriate style prompts based on their description and the scene context.
      PROMPT

      response = RubyLLM.chat.with_schema(DialogueSchema).ask(prompt)

      # The response structure matches the Audio model content expectation (array of blocks)
      content_blocks = response.content["dialogue"]["blocks"]

      @narration_scene.update!(dialogue_content: content_blocks)
    end
  end
end
