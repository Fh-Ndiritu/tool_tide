class MaskValidatorJob < ApplicationJob
  queue_as :default

  def perform(id)
    @mask_request = MaskRequest.find(id)
    @mask_request.update!(user_error: nil, progress: :validating)

    unless @mask_request.mask.attached?
      @mask_request.update!(user_error: I18n.t("permitted_errors.missing_drawing", progress: :mask_invalid))
      return
    end

    threshold = 1
    if painted_percentage < threshold
      @mask_request.update!(user_error: I18n.t("permitted_errors.missing_drawing", progress: :mask_invalid))
      return
    end

    @mask_request.validated!
  end

  private

  def painted_percentage
    image = MiniMagick::Image.read(@mask_request.mask.download)
    gray_image = image.colorspace("Gray").threshold("50%")

    mean = gray_image.data.dig("channelStatistics", "gray", "mean")
    max = gray_image.data.dig("channelStatistics", "gray", "max")

    return 0 unless mean

   # Max will be 1 or 255 while mean at 0 means all black while at 1/255 means all white
   (max - mean).to_f / max * 100
  end
end
