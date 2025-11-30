class VideoProductionJob < ApplicationJob
  queue_as :default

  def perform(chapter_id)
    chapter = Chapter.find(chapter_id)
    chapter.update!(status: "processing")

    # Step 1: Structure Chapter
    VideoPipeline::StructureChapterService.new(chapter).perform

    chapter.subchapters.order(:order).take(1).each do |subchapter|
      # Step 2: Generate Scenes
      VideoPipeline::GenerateScenesService.new(subchapter).perform

      subchapter.narration_scenes.order(:order).each do |scene|
        # Step 3: Generate Narration & Dialogue
        VideoPipeline::GenerateNarrationService.new(scene).perform

        # Step 4: Generate Audio
        VideoPipeline::GenerateAudioService.new(scene).perform

        # Reload scene to get audio association if needed, though audio is created.
        # Wait for audio generation?
        # GenerateAudioService creates Audio record.
        # Audio record callback triggers GeminiTts synchronously (in this process).
        # So audio should be attached now.

        # Step 5: Generate Image Prompts
        VideoPipeline::GenerateImagePromptsService.new(scene).perform

        # Step 6: Generate Images
        # TODO: Debug from here
        VideoPipeline::GenerateImagesService.new(scene).perform

        # Step 7: Stitch Scene Video
        VideoPipeline::StitchVideoService.new(scene).perform
      end

      # Step 8: Stitch Subchapter Video
      scene_videos = subchapter.narration_scenes.order(:order).map(&:video)
      VideoPipeline::ConcatVideosService.new(subchapter, scene_videos).perform
    end

    # Step 9: Stitch Chapter Video
    subchapter_videos = chapter.subchapters.order(:order).map(&:video)
    VideoPipeline::ConcatVideosService.new(chapter, subchapter_videos).perform

    chapter.update!(status: "completed")
  rescue => e
    chapter.update!(status: "failed")
    Rails.logger.error("VideoProductionJob failed for Chapter #{chapter_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
  end
end
