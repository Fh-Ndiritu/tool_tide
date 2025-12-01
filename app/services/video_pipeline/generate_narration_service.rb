module VideoPipeline
  class NarrationSchema < RubyLLM::Schema
    object :narration do
      string :text, description: "The full narration text in a lively and engaging style."
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
        Your task is to generate a dynamic, deeply atmospheric, and emotionally resonant narration for the following scene overview:
        "#{@narration_scene.content_overview}"

        ## Narration Style and Requirements
          Use these steps to generate a narration:
          1. Carefully analyze the scene overview and expand it into a full narrative that is rich in sensory details and logical prose.
          2. The narration must advance the core plot points detailed in the scene overview. The primary goal is coherence and understanding.
          3. You must use a TikTok or Short Story style to ensure we include details, stay engaging and concise.
          4. Capture a provocative and engaging tone that will keep the audience interested.
          5. Review the final narration to ensure it is clear and engaging and indeed expands on the scene overview without going beyond the scope of the scene overview.
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
      Your task is to convert the provided 'Narration' text into a structured, multi-speaker dialogue script.
      USE dialogue only when necessary which is rare, and when it is necessary, use it to advance the plot or to express a character's emotions.
      Otherwise just chunk the narration into Huria's interjections.

      Narration:
      "#{@narration_scene.narration_text}"

      Character Descriptions:
      #{character_descriptions}

      Available Voices (for non-Huria speakers):
      #{available_voices}

      ## Rules for Dialogue Conversion
      1.  **Narrator:** The sole Narrator must always be **Huria**.
      2.  **Fidelity to Content:** Distribute the key plot points and emotional beats from the 'Narration' into the character dialogue and Huria's interjections.
      3.  **Speaker Selection:** Select non-Huria speakers from the 'Available Voices' list based on gender, character type, and scene context.
      4.  **Output Structure:** Structure the output as an Array of Hashes. Each Hash represents a style block and must contain the following keys: 'style_prompt' and 'turns'.
      5. DO NOT include asterisks ** or any visual formatting in the output.

      ## Style Prompt Generation
      5.  **Huria's Style (Narrator):**
          * **Default:** "Tiktok Narration Style. Maintain a fast, clear narrative pace. The tone must be authoritative and engaging."
          * **Adaptation:** Adapt this style prompt if the scene requires tone adjustments etc.
      6.  **Character Style (Non-Huria):**
          * Generate unique and appropriate 'style_prompt' strings for each conversational character based on their 'Character Descriptions' and the current scene's context. Styles should introduce contrast (e.g., sharp and cynical, low and fearful, warm and hesitant).
      7. DO NOT use dialogue just for the sake of it. Use it only when it is necessary to advance the plot or to express a character's emotions.

      ## Example Output Structure (Reference)
      [
        {
          "style_prompt": "Tiktok Narration Style. Maintain a fast, clear narrative pace. The tone must be authoritative and engaging.",
          "turns": [
            {"speaker": "Huria", "text": "What happened in the final hours before Julius left the city?"}
          ]
        },
        {
          "style_prompt": "Low, gravelly male voice. Sharp and cynical tone, delivered with a slow, deliberate pace.",
          "turns": [
            {"speaker": "Karuri", "text": "I told you this relic was cursed, didn't I?"}
          ]
        },
        // ... more blocks
      ]
      PROMPT

      response = RubyLLM.chat.with_schema(DialogueSchema).ask(prompt)

      # The response structure matches the Audio model content expectation (array of blocks)
      content_blocks = response.content["dialogue"]["blocks"]

      @narration_scene.update!(dialogue_content: content_blocks)
    end
  end
end
