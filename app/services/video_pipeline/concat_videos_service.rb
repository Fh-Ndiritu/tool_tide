module VideoPipeline
  class ConcatVideosService
    def initialize(output_record, input_videos)
      @output_record = output_record # Chapter or Subchapter
      @input_videos = input_videos # List of ActiveStorage::Attached::One
    end

    def perform
      return if @input_videos.empty?

      Dir.mktmpdir do |dir|
        input_txt_path = File.join(dir, "input.txt")

        File.open(input_txt_path, "w") do |f|
          @input_videos.each_with_index do |video, index|
            next unless video.attached?

            video_path = File.join(dir, "video_#{index}.mp4")
            File.open(video_path, "wb") do |v_file|
              v_file.write(video.download)
            end

            f.puts "file '#{video_path}'"
          end
        end

        output_path = File.join(dir, "output.mp4")

        # Run ffmpeg concat
        command = "ffmpeg -f concat -safe 0 -i #{input_txt_path} -c copy #{output_path}"

        system(command)

        if File.exist?(output_path)
          @output_record.video.attach(
            io: File.open(output_path),
            filename: "concat_#{@output_record.class.name.downcase}_#{@output_record.id}.mp4",
            content_type: "video/mp4"
          )
        else
          Rails.logger.error("FFMPEG failed to concatenate videos for #{@output_record.class.name} #{@output_record.id}")
        end
      end
    end
  end
end
