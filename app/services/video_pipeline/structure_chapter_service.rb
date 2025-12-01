module VideoPipeline
  class SubchapterListSchema < RubyLLM::Schema
    object :structure do
      array :subchapters, description: "List of 4 subchapters" do
        object do
          string :title, description: "Title of the subchapter"
          string :overview, description: "Brief overview of the content discussed in this subchapter"
        end
      end
    end
  end

  class StructureChapterService
    def initialize(chapter)
      @chapter = chapter
    end

    def perform
      #  prompt = "You are a video production assistant. We need to generate a 12 minute episode based on the following content:\n\n#{@chapter.content}\n\nDefine 4 Subchapters where each is 3 minutes long. Define the content each subchapter will discuss briefly while ensuring logical flow in narration."

      prompt = "You are a video production assistant. We need to generate a 3 minute episode based on
      the following content:\n\n#{@chapter.content}\n\n
      Define the content this subchapter will discuss briefly while ensuring logical flow in narration."

      response = RubyLLM.chat.with_schema(SubchapterListSchema).ask(prompt)

      data = response.content["structure"]["subchapters"]

      ActiveRecord::Base.transaction do
        @chapter.subchapters.destroy_all
        data.each_with_index do |sub_data, index|
          @chapter.subchapters.create!(
            title: sub_data["title"],
            overview: sub_data["overview"],
            order: index + 1
          )
        end
      end
    end
  end
end
