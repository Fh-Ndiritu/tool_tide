module VideoPipeline
  class SceneListSchema < RubyLLM::Schema
    object :structure do
      array :scenes, description: "List of 3 narration scenes" do
        object do
          string :content_overview, description: "Overview of the content for this scene"
        end
      end
    end
  end

  class GenerateScenesService
    def initialize(subchapter)
      @subchapter = subchapter
    end

    def perform
      prompt = "We need to split the following subchapter content into 2 Narration Scenes which are each 1.5 minutes long.
      Ensure the content stays logical and in prose and focusses to tell the story in detail and within such a small amount of time. \n\nSubchapter Overview: #{@subchapter.overview}"

      response = RubyLLM.chat.with_schema(SceneListSchema).ask(prompt)

      data = response.content["structure"]["scenes"]

      ActiveRecord::Base.transaction do
        @subchapter.narration_scenes.destroy_all
        data.each_with_index do |scene_data, index|
          @subchapter.narration_scenes.create!(
            content_overview: scene_data["content_overview"],
            order: index + 1,
            duration: 60 # 1 minute in seconds
          )
        end
      end
    end
  end
end
