class ProjectOverlayGenerator
  # Standard violet paint color used in frontend (hex #8A2BE2 approx, or similar)
  # We will check specifically for non-transparent pixels that are effectively "paint".
  # Assuming the mask is transparent background + paint.

  def initialize(project_layer)
    @layer = project_layer
  end

  def self.perform(project_layer)
    new(project_layer).perform
  end

  def perform
    return unless @layer.project.present? # Safety

    # 1. Identify Base Image (Parent Result or Project Original)
    base_image_blob = resolve_base_image
    unless base_image_blob
      Rails.logger.warn("ProjectOverlayGenerator: No base image found for layer #{@layer.id}")
      return
    end

    # 2. Identify Mask Image
    mask_blob = @layer.mask.try(:blob)

    # 3. Create Overlay
    # If no mask, the overlay is just the base image (or we don't generate one? User said "generate an overlay").
    # If no mask, overlay = base.

    generated_overlay_blob = composite_images(base_image_blob, mask_blob)

    # 4. Attach Overlay
    @layer.overlay.attach(generated_overlay_blob)

    # 5. Detect Mask Presence (Robust Check)
    has_purple = mask_blob ? has_painted_content?(mask_blob) : false

    has_purple

  rescue StandardError => e
    Rails.logger.error("ProjectOverlayGenerator Failed: #{e.message}")
    raise "ProjectOverlayGenerator Failed: #{e.message}"
  end

  private

  def resolve_base_image
    # Parent's result, or Parent's overlay?
    # Usually: Parent -> Result.
    # If Parent is Root (Original), it has `image`.

    parent = @layer.parent
    if parent
      parent.result_image.attached? ? parent.result_image.blob : parent.image.blob
    else
      # Fallback to root or self if self is root (but job is for generated layer)
      # If this layer IS root, it shouldn't be generating? (Layer type generated)
      nil
    end
  end

  def composite_images(base_blob, mask_blob)
    return base_blob unless mask_blob

    base_img = MiniMagick::Image.read(base_blob.download)
    mask_img = MiniMagick::Image.read(mask_blob.download)

    # Resize mask to match base if needed
    unless base_img.dimensions == mask_img.dimensions
      mask_img.resize "#{base_img.width}x#{base_img.height}!"
    end

    # Standardize Mask Transparency & Color
    # Make white transparent, then colorize all non-transparent pixels to Purple (#8A2BE2)
    # This ensures consistency regardless of the input mask color
    mask_img.combine_options do |c|
      c.fuzz "10%"
      c.transparent "white"
      c.fill "#8A2BE2"
      c.colorize "100%"
    end

    # Composite
    # Logic from MaskRequest: dissolve 70, gravity Center
    result = base_img.composite(mask_img) do |c|
      c.dissolve "70"
      c.gravity "Center"
    end

    # Upload result
    io = StringIO.new(result.to_blob)
    ActiveStorage::Blob.create_and_upload!(
      io: io,
      filename: "overlay_#{SecureRandom.hex(4)}.png",
      content_type: "image/png"
    )
  end

  def has_painted_content?(mask_blob)
    # Logic adapted from MaskValidatorJob#painted_percentage
    # Converts to greyscale and calculates the percentage of the image that is "dark" (painted)
    # assuming the background is white/transparent (light).

    image = MiniMagick::Image.read(mask_blob.download)

    # Ensure alpha is flattened to white if transparent, to avoid transparency being counted as black
    image.alpha("remove")
    image.background("white")

    gray_image = image.colorspace("Gray").threshold("50%")

    # MiniMagick data parsing can vary by version, handle both caps
    stats = gray_image.data["channelStatistics"]["Gray"] || gray_image.data["channelStatistics"]["gray"]

    return false unless stats

    mean = stats["mean"]
    max = stats["max"]

    return false if max.zero?

    # Calculate percentage of "dark" pixels
    # If image is all white: mean = max -> 0%
    # If image is all black: mean = 0 -> 100%
    percentage = (max - mean).to_f / max * 100

    # Threshold: MaskValidatorJob uses 5%.
    # We use a slightly lower threshold (1%) to detect even valid small edits,
    # distinguishing them from accidental noise or empty masks.
    percentage > 1.0
  end
end
