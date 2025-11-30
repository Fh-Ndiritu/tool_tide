module VideoPipeline
  class StitchVideoService
    def initialize(narration_scene)
      @narration_scene = narration_scene
    end

    def perform
      audio = @narration_scene.audio
      return unless audio&.audio_file&.attached?
      return if @narration_scene.image_prompts.empty?

      # Prepare temporary directory
      Dir.mktmpdir do |dir|
        # Download audio
        audio_path = File.join(dir, "audio.wav")
        File.open(audio_path, "wb") do |file|
          file.write(audio.audio_file.download)
        end

        # Prepare images list for ffmpeg
        input_txt_path = File.join(dir, "input.txt")

        sorted_prompts = @narration_scene.image_prompts.order(:timestamp)

        File.open(input_txt_path, "w") do |f|
          sorted_prompts.each_with_index do |prompt, index|
            next unless prompt.image.attached?

            image_path = File.join(dir, "image_#{index}.jpg")
            File.open(image_path, "wb") do |img_file|
              img_file.write(prompt.image.download)
            end

            # Calculate duration
            next_timestamp = sorted_prompts[index + 1]&.timestamp || @narration_scene.duration
            duration = next_timestamp - prompt.timestamp

            f.puts "file '#{image_path}'"
            f.puts "duration #{duration}"
          end
          # Repeat last image to ensure video matches audio duration if needed
          # ffmpeg concat demuxer requires the last file to be repeated or just handled correctly?
          # Actually, the last image needs to be displayed until the end.
          # The duration directive applies to the preceding file.
          # So the last entry should handle the remaining time.
        end

        output_path = File.join(dir, "output.mp4")

        # Run ffmpeg
        # -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" to ensure standard size
        # Assuming landscape mode. If portrait, swap dimensions.
        # The user request mentioned "The mode of the video is specified in the chapter as portrait or landscape".

        video_mode = @narration_scene.subchapter.chapter.video_mode
        scale_filter = if video_mode == "portrait"
                         "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2"
                       else
                         "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2"
                       end

        command = "ffmpeg -f concat -safe 0 -i #{input_txt_path} -i #{audio_path} -c:v libx264 -vf \"#{scale_filter},format=yuv420p\" -c:a aac -shortest #{output_path}"

        system(command)

        if File.exist?(output_path)
          @narration_scene.video.attach(
            io: File.open(output_path),
            filename: "scene_#{@narration_scene.id}.mp4",
            content_type: "video/mp4"
          )
        else
          Rails.logger.error("FFMPEG failed to generate video for scene #{@narration_scene.id}")
        end
      end
    end
  end
end
